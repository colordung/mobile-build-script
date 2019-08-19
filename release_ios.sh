#!/bin/bash

error_exit()
{
	echo "${1:-"Unknown Error"}" 1>&2
	exit 1
}

# 빌드 정보
TARGET=$1
PROJECT_NAME=$2
XCODEVERSION=$3
SCHEME=$4
WORKSPACE=$5
DEPTH=$6
PROVISIONING_NAME=$7
echo $1
echo $2
echo $3
echo $4
echo $5
echo $6
echo $7

# 빌드 서버의 로그인 암호 [키체인 로그인을 위해 필요.]
KEYCHAIN_PW=PASS


if [ $TARGET = "QA" ] || [ $TARGET = "PROD" ] || [ $TARGET = "DIST" ]
  then
    echo "#####################################"
    echo "✅ iOS ${TARGET} 빌드를 시작합니다."
    echo "✅ 빌드 순서 안내"
    echo "✅ 1. 소스파일 압축해제(해당 날짜 폴더)"
    echo "✅ iOS ${TARGET} 빌드"
    echo "#####################################"
else
  error_exit "파라메터 확인필요"
fi


#작업경로 이동
cd ~/colordung/$PROJECT_NAME/Work || error_exit "폴더 이동 실패"
echo "✅ 현재위치 : ${PWD}"

# 파일 압축 해제.
echo "#####################################"
echo "✅ ${TAR_FILE_NAME} 압축을 해제합니다."
echo "#####################################"

if [ -s $PROJECT_NAME.tar ]
  then
    rm -rf $PROJECT_NAME || error_exit "기존폴더 삭제 실패"
    mkdir $PROJECT_NAME || error_exit "압축해제 폴더 생성 실패"
    tar zxvf $PROJECT_NAME.tar -C $PROJECT_NAME || error_exit "압축해제 실패"
else
  error_exit "소스파일없음"
fi

# 날짜 폴더명
DATE=`date '+%Y%m%d%H%M%S'`

# 파일 생성 및 이동.
echo "✅ ${DATE} 폴더 생성합니다.."
mkdir $DATE || error_exit "${DATE} 폴더 생성 실패"

echo "✅ ${PROJECT_NAME} 폴더를 ${DATE}/${PROJECT_NAME} 경로로 이동합니다."
mv $PROJECT_NAME $DATE || error_exit "폴더 이동 실패"
cd $DATE/$PROJECT_NAME || error_exit "위치이동 실패"

[ $DEPTH = "none" ] || cd $DEPTH || error_exit "위치이동 실패"
echo "✅ 현재위치 : ${PWD}"

# IPA 아카이브 시작.
echo "#####################################"
echo "✅ IPA 아카이브를 시작합니다."
echo "#####################################"

#Fabric 파일 경로.
#FABRIC_PATH=$PWD/Pods/Fabric
#FABRIC_RUN=$FABRIC_PATH/run
#FABRIC_UPLOAD_DSYM=$FABRIC_PATH/uploadDSYM

# 권한 변경.
echo "✅ 파일 권한 변경합니다."
#chmod 744 $FABRIC_RUN
#chmod 744 $FABRIC_UPLOAD_DSYM

# 키체인 잠금 해제.
# https://stackoverflow.com/questions/9245149/jenkins-on-os-x-xcodebuild-gives-code-sign-error  
echo "✅ 키체인 잠금을 해제합니다."
security unlock-keychain -p $KEYCHAIN_PW $HOME/Library/Keychains/login.keychain


#######
# TODO 난독화 스크립트 추가
#######


#choose xcode-select version
echo "✅ xcode-select ${XCODEVERSION}."
if [ $XCODEVERSION = "9" ]; then
  sudo xcode-select -switch ~/dev/Xcode.app
elif [ $XCODEVERSION = "10" ]; then
  sudo xcode-select -switch /Applications/Xcode.app
fi

# 빌드 스크립트 실행.
echo "✅ 빌드 스크립트 실행합니다."
mkdir -p build/ || error_exit "build 폴더 생성 실패"
if [ $WORKSPACE = "none" ]; then
xcodebuild archive \
 -verbose \
 -jobs 2 \
 -scheme "$SCHEME" \
 -configuration $TARGET \
 -derivedDataPath "$PWD/DerivedData" \
 -archivePath ./build/$PROJECT_NAME.xcarchive \
  || error_exit "archive 실패"
else
xcodebuild archive \
 -verbose \
 -jobs 2 \
 -workspace $WORKSPACE.xcworkspace \
 -scheme "$SCHEME" \
 -configuration $TARGET \
 -derivedDataPath "$PWD/DerivedData" \
 -archivePath ./build/$PROJECT_NAME.xcarchive \
  || error_exit "archive 실패"
fi


rm -rf ./IPA || error_exit "IPA 삭제 실패"

#make export options

if [ $TARGET = "QA" ]; then
  options="export_QA.plist"
elif [ $TARGET = "PROD" ] || [ $TARGET = "DIST" ]; then
  options="export_PROD.plist"
fi

prov=$(awk -F  "= " '/PROVISIONING_PROFILE_SPECIFIER/ {gsub("\"","",$2); gsub(";","",$2); print $2}' $PROJECT_NAME.xcodeproj/project.pbxproj)

echo "✅ PROVISIONING LIST : ${prov}"
echo "✅ PROVISIONING NAME : ${PROVISIONING_NAME}"

line=$(awk -F  "= " '/PROVISIONING_PROFILE_SPECIFIER/ {gsub("\"","",$2); gsub(";","",$2); print $2}' $PROJECT_NAME.xcodeproj/project.pbxproj | awk '{print NR $0}' | awk -F "$PROVISIONING_NAME" '/'"$PROVISIONING_NAME"'/ {print $1}' | awk 'END{print}')

if [ $line ]; then
  echo "✅ P_line : ${line}"
else
  error_exit "✅ 프로비져닝 이름 확인필요"
fi


P_KEY=$(awk -F  "= " '/PRODUCT_BUNDLE_IDENTIFIER/ {gsub("\"","",$2); gsub(";","",$2); print $2}' $PROJECT_NAME.xcodeproj/project.pbxproj | sed -n ''"$line"'p')


echo "✅ P_KEY : ${P_KEY}"
echo "✅ P_VALUE : ${PROVISIONING_NAME}"

sed 's/CHANGE_KEY/'"$P_KEY"'/g' ~/export.plist > ~/$PROJECT_NAME/tmp_export.plist
sed 's/CHANGE_VALUE/'"$PROVISIONING_NAME"'/g' ~/$PROJECT_NAME/tmp_export.plist > ~/$PROJECT_NAME/"$options"


#now create the .IPA using export options specified in property list files
xcodebuild \
 -exportArchive \
 -verbose \
 -archivePath ./build/$PROJECT_NAME.xcarchive \
 -exportPath ./IPA/"$TARGET" \
 -exportOptionsPlist ~/$PROJECT_NAME/"$options" \
 || error_exit "export 실패"

#exportOptionsPlist ~/$PROJECT_NAME/Work/$DATE/$PROJECT_NAME/exportOptions/"$options" \
#exportOptionsPlist ~/$PROJECT_NAME/"$options" \

#clean up build
rm -rf ./build || error_exit "build 삭제 실패"

#clean up DerivedData
rm -rf ./DerivedData || error_exit "DerivedData 삭제 실패"

# IPA 업로드.
IPA_PATH=/IPA/$TARGET

echo "✅ 빌드 결과 파일 이동."

cp $PWD$IPA_PATH/$SCHEME.ipa ~/$PROJECT_NAME/Work/$SCHEME.ipa || error_exit "결과 파일 이동 실패"

# 기존 소스 파일 제거.
#echo "✅ 기존 소스 파일을 제거합니다."
#array=(20*/)
#size=${#array[@]}
#if [ size>10 ]
#then
#  for ((i=0; i<size-10; i++)) do
#    echo $i "${array[i]}"
#    rm -rf ${array[i]}
#  done
#fi

echo "#####################################"
echo "✅ 스크립트 실행이 완료되었습니다."
echo "#####################################"
