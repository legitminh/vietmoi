#include <jni.h>
#include <cstdint>
#include <vector>
#include "sieuviet.h"

static sv_engine_t engine(jlong handle) { return reinterpret_cast<sv_engine_t>(static_cast<uintptr_t>(handle)); }
static void fail(JNIEnv *env, const char *message) {
    env->ThrowNew(env->FindClass("java/lang/IllegalStateException"), message);
}
// JNI's NewStringUTF uses modified UTF-8. Decode standard UTF-8 explicitly so
// future supplementary-plane guide labels also cross the boundary correctly.
static jstring string(JNIEnv *env, const std::vector<char> &bytes, int64_t length) {
    jbyteArray data = env->NewByteArray(static_cast<jsize>(length - 1));
    if (!data) return nullptr;
    env->SetByteArrayRegion(data, 0, static_cast<jsize>(length - 1), reinterpret_cast<const jbyte *>(bytes.data()));
    jclass cls = env->FindClass("java/lang/String");
    jmethodID init = env->GetMethodID(cls, "<init>", "([BLjava/lang/String;)V");
    jstring encoding = env->NewStringUTF("UTF-8");
    auto result = static_cast<jstring>(env->NewObject(cls, init, data, encoding));
    env->DeleteLocalRef(data);
    env->DeleteLocalRef(encoding);
    env->DeleteLocalRef(cls);
    return result;
}

extern "C" JNIEXPORT jlong JNICALL Java_com_minh_sieuviet_android_NativeEngine_nativeCreate(JNIEnv *env, jobject, jint output) {
    if (sv_engine_abi_version() != 1) { fail(env, "Incompatible Sieuviet engine ABI"); return 0; }
    sv_engine_t handle = sv_engine_create(output);
    if (!handle) fail(env, "Invalid output configuration");
    return static_cast<jlong>(reinterpret_cast<uintptr_t>(handle));
}
extern "C" JNIEXPORT void JNICALL Java_com_minh_sieuviet_android_NativeEngine_nativeDestroy(JNIEnv *, jobject, jlong handle) { sv_engine_destroy(engine(handle)); }
extern "C" JNIEXPORT jint JNICALL Java_com_minh_sieuviet_android_NativeEngine_nativeDispatch(JNIEnv *, jobject, jlong handle, jint command, jint argument) {
    return sv_engine_dispatch(engine(handle), command, argument);
}
extern "C" JNIEXPORT jboolean JNICALL Java_com_minh_sieuviet_android_NativeEngine_nativeObserveKey(JNIEnv *, jobject, jlong handle, jint usage, jboolean down, jdouble timestamp, jboolean other) {
    return sv_engine_observe_key(engine(handle), usage, down ? 1 : 0, timestamp, other ? 1 : 0) == 1;
}
extern "C" JNIEXPORT jstring JNICALL Java_com_minh_sieuviet_android_NativeEngine_nativeText(JNIEnv *env, jobject, jlong handle) {
    int64_t count = sv_engine_copy_text(engine(handle), nullptr, 0);
    if (count < 1 || count > 65536) { fail(env, "Invalid engine text"); return nullptr; }
    std::vector<char> data(static_cast<size_t>(count));
    sv_engine_copy_text(engine(handle), data.data(), data.size());
    return string(env, data, count);
}
extern "C" JNIEXPORT jstring JNICALL Java_com_minh_sieuviet_android_NativeEngine_nativeState(JNIEnv *env, jobject, jlong handle, jint input) {
    int64_t count = sv_engine_copy_state(engine(handle), input, nullptr, 0);
    if (count < 1 || count > 65536) { fail(env, "Invalid engine state"); return nullptr; }
    std::vector<char> data(static_cast<size_t>(count));
    sv_engine_copy_state(engine(handle), input, data.data(), data.size());
    return string(env, data, count);
}
