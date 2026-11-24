#ifndef SIEUVIET_ENGINE_H
#define SIEUVIET_ENGINE_H
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Engine ABI 1. A document/IME session API will be added separately. */
typedef void *sv_engine_t;
enum sv_output { SV_SIEUVIET = 0, SV_QUOC_NGU = 1 };
/* What the keys spell: siêu việt's own choices or quốc ngữ's. Independent of the output. */
enum sv_input_mode { SV_INPUT_SIEUVIET = 0, SV_INPUT_QUOC_NGU = 1 };
enum sv_command {
    SV_KEY = 0, SV_COMPONENT = 1, SV_BACKSPACE = 2, SV_CANCEL = 3,
    SV_FINISH = 4, SV_TOGGLE_ASCII = 5, SV_SPACE = 6, SV_CLEAR = 7
};
enum sv_effect {
    SV_NONE = 0, SV_MARKED = 1, SV_COMMIT = 2, SV_CANCELLED = 3, SV_DELETE_CYCLE = 4
};
enum sv_error { SV_INVALID_ARGUMENT = -1, SV_UNMAPPED_KEY = -2 };

uint32_t sv_engine_abi_version(void);
/* Invalid output returns NULL. Every successful create needs exactly one destroy. */
sv_engine_t sv_engine_create(int32_t output);
/* sv_engine_create with an sv_input_mode (create uses SV_INPUT_SIEUVIET). Invalid values return NULL. */
sv_engine_t sv_engine_create_with_input(int32_t output, int32_t input_mode);
/* NULL is harmless; all other handles must be live values returned by create.
   Never reuse or double-destroy a handle. Calls on a handle must be serialized. */
void sv_engine_destroy(sv_engine_t engine);
/* Adaptive punctuation (Vietnamese). `tail` is the UTF-8 block the host committed just
   before the caret, ending in its automatic space; `typed` is the UTF-8 text of the key.
   For a phrase mark (, . ? ! ; : …) it copies the replacement for `tail` ("quá " + "!" →
   "quá! ") and returns the bytes INCLUDING the trailing NUL, as the copy functions do;
   it returns 0 when the key types as usual. The host deletes `tail` only after verifying it. */
int64_t sv_adaptive_punctuation(const char *tail, const char *typed, char *buffer, uint64_t capacity);
/* Returns an effect or negative sv_error. SV_KEY uses page-0x07 USB HID usages.
   SV_COMPONENT uses current inventory order. Other commands require argument=0.
   Errors preserve the previous state/effect. The host applies each effect once;
   reads never re-dispatch events. SV_DELETE_CYCLE is only a host request, never
   permission to delete unverified text. SV_NONE needs host handling for native
   Backspace when idle. No host document operations occur inside this library. */
int32_t sv_engine_dispatch(sv_engine_t engine, int32_t command, int32_t argument);
int32_t sv_engine_phase(sv_engine_t engine); /* 0 initial, 1 vowel, 2 final, 3 tone */
int32_t sv_engine_ascii(sv_engine_t engine); /* 0/1, or SV_INVALID_ARGUMENT */
/* Copy UTF-8 into caller storage. Return required bytes INCLUDING trailing NUL,
   or a negative error. NULL/0 queries size. Too-small buffers are untouched.
   No internal pointer escapes; reading is valid until destroy. */
int64_t sv_engine_copy_text(sv_engine_t engine, char *buffer, uint64_t capacity);
int64_t sv_engine_copy_preview(sv_engine_t engine, char *buffer, uint64_t capacity);
/* Unavailable/unsupported key => SV_UNMAPPED_KEY, not an empty-string label.
   Empty initial/final labels are the visible UTF-8 empty-set glyph. */
int64_t sv_engine_copy_label(sv_engine_t engine, int32_t hid_usage, char *buffer, uint64_t capacity);
/* UTF-8 JSON guide/state from the shared layout. input_type: 0 ASCII+, 1 grid4x8.
   Invalid input_type returns SV_INVALID_ARGUMENT without mutating the engine. */
int64_t sv_engine_copy_state(sv_engine_t engine, int32_t input_type, char *buffer, uint64_t capacity);
/* Shared Shift tap/hold/chord detector. Returns 1 for a toggle gesture, 0 for none,
   or SV_INVALID_ARGUMENT. Does not dispatch a toggle or mutate composition.
   usage is a page-0x07 HID usage; timestamp is monotonic seconds. */
int32_t sv_engine_observe_key(sv_engine_t engine, int32_t usage, int32_t down, double timestamp, int32_t other_modifiers);
/* Nonmutating event eligibility and shared ASCII+/grid physical routing. */
int32_t sv_engine_wants_key(sv_engine_t engine, int32_t input_type, int32_t hid_usage);
int32_t sv_engine_dispatch_key(sv_engine_t engine, int32_t input_type, int32_t hid_usage);
/* Framework-native panels can display this shared guide without a JSON parser. */
int64_t sv_engine_copy_guide(sv_engine_t engine, int32_t input_type, char *buffer, uint64_t capacity);

#ifdef __cplusplus
}
#endif
#endif
