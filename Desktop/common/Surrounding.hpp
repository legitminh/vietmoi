#pragma once
#include <optional>
#include <string>
#include <algorithm>

namespace sv {
// Native adapters convert their toolkit's cursor units to UTF-8 byte offsets.
struct Surrounding { std::string text; size_t cursor = 0, anchor = 0; };
class CommitProof {
    std::optional<Surrounding> expected_; std::string value_;
public:
    void reset() { expected_.reset(); value_.clear(); }
    void record(const std::optional<Surrounding> &before, const std::string &value) {
        reset(); if (!before || before->cursor > before->text.size() || before->anchor > before->text.size()) return;
        auto expected = *before; const auto start = std::min(expected.cursor, expected.anchor);
        expected.text.replace(start, std::max(expected.cursor, expected.anchor) - start, value);
        expected.cursor = expected.anchor = start + value.size(); expected_ = std::move(expected); value_ = value;
    }
    bool matches(const std::optional<Surrounding> &now, const std::string &value) const {
        return expected_ && now && value == value_ && now->cursor == now->anchor &&
            now->cursor == expected_->cursor && now->text == expected_->text;
    }
};
}
