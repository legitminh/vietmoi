#include "sieuviet.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static unsigned checks;
#define CHECK(condition) do { ++checks; if (!(condition)) { \
    fprintf(stderr, "C ABI failure at line %d: %s\n", __LINE__, #condition); exit(1); \
} } while (0)

static int32_t usage(char key) { return key == ';' ? 0x33 : (int32_t)(key - 'a' + 4); }

static void expect_text(sv_engine_t engine, const char *expected) {
    char buffer[128];
    memset(buffer, 0x55, sizeof buffer);
    const int64_t size = (int64_t)strlen(expected) + 1;
    CHECK(sv_engine_copy_text(engine, NULL, 0) == size);
    CHECK(sv_engine_copy_text(engine, buffer, (uint64_t)size - 1) == size);
    CHECK(buffer[0] == 0x55); /* Failed copies cannot truncate UTF-8 or modify storage. */
    CHECK(sv_engine_copy_text(engine, buffer, (uint64_t)size) == size);
    CHECK(strcmp(buffer, expected) == 0);
    CHECK(buffer[size] == 0x55); /* Includes exactly one terminating NUL. */
}

static void word(const char *keys, int32_t output, const char *expected) {
    sv_engine_t engine = sv_engine_create(output);
    CHECK(engine != NULL);
    for (size_t index = 0; keys[index]; ++index) {
        CHECK(sv_engine_dispatch(engine, SV_KEY, usage(keys[index])) ==
              (keys[index + 1] ? SV_MARKED : SV_COMMIT));
    }
    CHECK(sv_engine_phase(engine) == 0);
    expect_text(engine, expected);
    CHECK(sv_engine_dispatch(engine, 99, 0) == SV_INVALID_ARGUMENT);
    CHECK(sv_engine_dispatch(engine, SV_CANCEL, 1) == SV_INVALID_ARGUMENT);
    CHECK(sv_engine_dispatch(engine, SV_COMPONENT, -1) == SV_INVALID_ARGUMENT);
    expect_text(engine, expected); /* Errors do not replay or overwrite the commit. */
    sv_engine_destroy(engine);
}

int main(void) {
    CHECK(sv_engine_abi_version() == 1);
    CHECK(sv_engine_create(-1) == NULL);
    CHECK(sv_engine_create(2) == NULL);
    sv_engine_destroy(NULL);
    CHECK(sv_engine_dispatch(NULL, SV_KEY, 4) == SV_INVALID_ARGUMENT);
    CHECK(sv_engine_phase(NULL) == SV_INVALID_ARGUMENT);
    CHECK(sv_engine_ascii(NULL) == SV_INVALID_ARGUMENT);
    CHECK(sv_engine_copy_text(NULL, NULL, 0) == SV_INVALID_ARGUMENT);
    CHECK(sv_engine_copy_preview(NULL, NULL, 0) == SV_INVALID_ARGUMENT);
    CHECK(sv_engine_copy_label(NULL, 4, NULL, 0) == SV_INVALID_ARGUMENT);
    CHECK(sv_engine_copy_state(NULL, 0, NULL, 0) == SV_INVALID_ARGUMENT);
    CHECK(sv_engine_observe_key(NULL, 0xe1, 1, 0, 0) == SV_INVALID_ARGUMENT);
    CHECK(sv_engine_wants_key(NULL, 0, 4) == SV_INVALID_ARGUMENT);
    CHECK(sv_engine_dispatch_key(NULL, 0, 4) == SV_INVALID_ARGUMENT);
    CHECK(sv_engine_copy_guide(NULL, 0, NULL, 0) == SV_INVALID_ARGUMENT);

    /* Quốc ngữ input mode spells with quốc ngữ's choices, into either output. */
    CHECK(sv_engine_create_with_input(SV_QUOC_NGU, 2) == NULL);
    CHECK(sv_engine_create_with_input(2, SV_INPUT_QUOC_NGU) == NULL);
    {
        sv_engine_t engine = sv_engine_create_with_input(SV_QUOC_NGU, SV_INPUT_QUOC_NGU);
        CHECK(engine);
        const char *keys = "qlcd";
        for (const char *key = keys; *key; ++key) sv_engine_dispatch(engine, SV_KEY, usage(*key));
        expect_text(engine, "quốc ");
        sv_engine_destroy(engine);
        engine = sv_engine_create_with_input(SV_SIEUVIET, SV_INPUT_QUOC_NGU);
        CHECK(engine);
        keys = "zses";
        for (const char *key = keys; *key; ++key) sv_engine_dispatch(engine, SV_KEY, usage(*key));
        expect_text(engine, "za ");
        sv_engine_destroy(engine);
    }

    word("msed", SV_SIEUVIET, "má ");
    word("mlnd", SV_QUOC_NGU, "muốn ");
    word("rwos", SV_SIEUVIET, "răo ");
    word("rwos", SV_QUOC_NGU, "rau ");
    word("frej", SV_QUOC_NGU, "phở ");
    word("xaqs", SV_QUOC_NGU, "xoong ");

    sv_engine_t first = sv_engine_create(SV_QUOC_NGU);
    sv_engine_t second = sv_engine_create(SV_SIEUVIET);
    CHECK(first && second);
    CHECK(sv_engine_wants_key(first, -1, 4) == SV_INVALID_ARGUMENT);
    CHECK(sv_engine_wants_key(first, 0, -1) == SV_INVALID_ARGUMENT);
    CHECK(sv_engine_wants_key(first, 0, 0x33) == 0);
    CHECK(sv_engine_dispatch_key(first, -1, 4) == SV_INVALID_ARGUMENT);
    CHECK(sv_engine_copy_guide(first, -1, NULL, 0) == SV_INVALID_ARGUMENT);
    CHECK(sv_engine_dispatch_key(first, 1, usage('r')) == SV_MARKED);
    CHECK(sv_engine_dispatch_key(first, 1, 0x20) == SV_MARKED);
    CHECK(sv_engine_dispatch_key(first, 1, 0x1e) == SV_MARKED);
    CHECK(sv_engine_dispatch_key(first, 1, 0x1f) == SV_COMMIT);
    expect_text(first, "má ");
    char guide[8192];
    memset(guide, 0x55, sizeof guide);
    int64_t guide_size = sv_engine_copy_guide(first, 0, NULL, 0);
    CHECK(guide_size > 1 && guide_size < (int64_t)sizeof guide);
    CHECK(sv_engine_copy_guide(first, 0, guide, 1) == guide_size);
    CHECK(guide[0] == 0x55);
    CHECK(sv_engine_copy_guide(first, 0, guide, sizeof guide) == guide_size);
    CHECK(strstr(guide, "m: m") != NULL);
    CHECK(sv_engine_copy_state(first, -1, NULL, 0) == SV_INVALID_ARGUMENT);
    int64_t state_size = sv_engine_copy_state(first, 0, NULL, 0);
    CHECK(state_size > 0 && state_size < 65536);
    char *state = (char *)malloc((size_t)state_size);
    CHECK(state != NULL);
    CHECK(sv_engine_copy_state(first, 0, state, (uint64_t)state_size) == state_size);
    CHECK(strstr(state, "\"phase\":0") != NULL);
    CHECK(strstr(state, "\"rows\"") != NULL);
    free(state);
    CHECK(sv_engine_observe_key(first, -1, 1, 0, 0) == SV_INVALID_ARGUMENT);
    CHECK(sv_engine_observe_key(first, 0xe1, 2, 0, 0) == SV_INVALID_ARGUMENT);
    CHECK(sv_engine_observe_key(first, 0xe1, 1, 0, 0) == 0);
    CHECK(sv_engine_observe_key(first, 0xe1, 0, 0.1, 0) == 1);
    CHECK(sv_engine_ascii(first) == 0);
    CHECK(sv_engine_copy_label(first, 0x33, NULL, 0) == SV_UNMAPPED_KEY);
    CHECK(sv_engine_dispatch(first, SV_KEY, usage('m')) == SV_MARKED);
    char buffer[32];
    CHECK(sv_engine_copy_preview(first, buffer, sizeof buffer) == 2);
    CHECK(strcmp(buffer, "m") == 0);
    CHECK(sv_engine_copy_label(first, 0x04, buffer, sizeof buffer) == 3);
    CHECK(strcmp(buffer, "oo") == 0);
    CHECK(sv_engine_dispatch(first, SV_TOGGLE_ASCII, 0) == SV_COMMIT);
    expect_text(first, "m");
    CHECK(sv_engine_ascii(first) == 1);
    CHECK(sv_engine_dispatch(first, SV_KEY, usage('y')) == SV_UNMAPPED_KEY);
    CHECK(sv_engine_phase(second) == 0 && sv_engine_ascii(second) == 0);
    sv_engine_destroy(first);
    CHECK(sv_engine_dispatch(second, SV_KEY, usage('m')) == SV_MARKED);
    CHECK(sv_engine_dispatch(second, SV_BACKSPACE, 0) == SV_CANCELLED);
    CHECK(sv_engine_dispatch(second, SV_BACKSPACE, 0) == SV_NONE);
    CHECK(sv_engine_dispatch(second, SV_KEY, usage('e')) == SV_MARKED);
    CHECK(sv_engine_dispatch(second, SV_SPACE, 0) == SV_COMMIT);
    expect_text(second, " ");
    CHECK(sv_engine_dispatch(second, SV_CLEAR, 0) == SV_DELETE_CYCLE);
    sv_engine_destroy(second);
    printf("Passed %u C ABI checks.\n", checks);
    return 0;
}
