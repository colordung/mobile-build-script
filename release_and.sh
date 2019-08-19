#!/bin/bash

error_exit()
{
	echo "${1:-"Unknown Error"}" 1>&2
	exit 1
}

export ANDROID_HOME=/Users/colordung/Library/Android/sdk || error_exit "SDK 위치등록 실패 "


# 빌드 정보
TARGET=$1
PROJECT_NAME=$2
APPNAME=$3
ABINAME=$4
PRODUCTFLAVORS=$5
OUTPUT=$6
APKSIGNER=~/Library/Android/sdk/build-tools/28.0.3/apksigner
SIGNFILE=~/android_sign
SIGNPASS= android_sign_pass

echo $PRODUCTFLAVORS 
[ $ABINAME = "none" ] && ABINAME=${ABINAME/none/""}
[ $PRODUCTFLAVORS = "none" ] && PRODUCTFLAVORS=${PRODUCTFLAVORS/none/""}
echo $PRODUCTFLAVORS

if [ $TARGET = "QA" ] || [ $TARGET = "PROD" ]
  then
    echo "#####################################"
    echo "✅ android ${TARGET} 빌드를 시작합니다."
    echo "✅ 빌드 순서 안내"
    echo "✅ 1. 소스파일 압축해제(해당 날짜 폴더)"
    echo "✅ 2. 프로퍼티 수정"
    echo "✅ android ${TARGET} 빌드"
    echo "✅ apk sign"
    echo "#####################################"
else
  error_exit "파라메터 확인필요"
fi

#작업경로 이동
cd ~/git/$PROJECT_NAME/Work || error_exit "폴더 이동 실패"
echo "✅ 현재위치 : ${PWD}"

# 파일 압축 해제.
echo "#####################################"
echo "✅ ${PROJECT_NAME.tar} 압축을 해제합니다."
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
# 빌드 스크립트
#./gradlew assembleRelease --stacktrace
BUILD_SH_FILE=./gradlew

# 파일 생성 및 이동.
echo "✅ ${DATE} 폴더 생성합니다.."
mkdir $DATE || error_exit "${DATE} 폴더 생성 실패"

echo "✅ ${PROJECT_NAME} 폴더를 ${DATE}/${PROJECT_NAME} 경로로 이동합니다."
mv $PROJECT_NAME $DATE || error_exit "폴더 이동 실패"
cd $DATE/$PROJECT_NAME || error_exit "위치이동 실패"
echo "✅ 현재위치 : ${PWD}"

# property 변경할까 삭제할까
# property 변경.
#echo "✅ property 변경합니다."
#rm local.properties || error_exit "기존 프러퍼티 삭제 실패"
#cp ../../local.properties . || error_exit "준비된 프러퍼티 복사 실패"

# property 삭제.
echo "✅ property 삭제합니다."
rm local.properties || error_exit "프러퍼티 삭제 실패"

# 권한 변경.
echo "✅ 파일 권한 변경합니다."
chmod 744 $BUILD_SH_FILE || error_exit "빌드 쉘 권한 변경 실패"

echo "✅ 빌드 스크립트 실행합니다."
${BUILD_SH_FILE} assemble --stacktrace || error_exit "빌드실패"

echo "✅ 빌드 결과 파일 이동."
#결과파일 카운트
APKCOUNT=$(find $APPNAME/build/outputs/apk$PRODUCTFLAVORS/release/ -type f  -maxdepth 1 -name "*.apk" | wc -l)
[ $APKCOUNT = 1 ] || error_exit "APK 파일 확인 필요"

if [ $TARGET = "QA" ]; then
  cp $APPNAME/build/outputs/apk$PRODUCTFLAVORS/$OUTPUT/*.apk ../../$PROJECT_NAME.apk || error_exit "결과 파일 이동 실패"
	if [ $OUTPUT = "release" ]; then
	echo "✅ app sign."
$APKSIGNER sign --ks $SIGNFILE --ks-pass pass:$SIGNPASS --v1-signing-enabled true --next-signer --v2-signing-enabled true ../../$PROJECT_NAME.apk || error_exit "싸이닝 실패"
	fi
elif [ $TARGET = "PROD" ]; then
  cp $APPNAME/build/outputs/apk$PRODUCTFLAVORS/release/*.apk ../../$PROJECT_NAME.apk || error_exit "결과 파일 이동 실패"
echo "✅ app sign."
$APKSIGNER sign --ks $SIGNFILE --ks-pass pass:$SIGNPASS --v1-signing-enabled true --next-signer --v2-signing-enabled true ../../$PROJECT_NAME.apk || error_exit "싸이닝 실패"
fi

echo "#####################################"
echo "✅ 스크립트 실행이 완료되었습니다."
echo "#####################################"

