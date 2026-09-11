# SPDX-FileCopyrightText: 2026 lyr339
# SPDX-License-Identifier: MIT

from types import SimpleNamespace

from pynguin.languagemodels.model import (
    _extract_generated_text,
    _openai_api_request,
)


def _model(relative_url: str):
    return SimpleNamespace(
        _model_base_url="https://example.com",
        _model_relative_url=relative_url,
        _complete_model="test-model",
        _temperature=0.8,
        _authorization_key="test-key",
    )


def test_builds_responses_api_request():
    url, payload, headers = _openai_api_request(
        _model("/v1/responses"), "def test_target():", "source"
    )

    assert url == "https://example.com/v1/responses"
    assert payload["model"] == "test-model"
    assert payload["input"] == "source\ndef test_target():"
    assert payload["max_output_tokens"] == 800
    assert payload["reasoning"] == {"effort": "low"}
    assert headers["Authorization"] == "Bearer test-key"


def test_builds_chat_completions_request():
    url, payload, _ = _openai_api_request(
        _model("/v1/chat/completions"), "def test_target():", "source"
    )

    assert url == "https://example.com/v1/chat/completions"
    assert payload["messages"] == [
        {"role": "user", "content": "source\ndef test_target():"}
    ]


def test_extracts_text_from_supported_api_shapes():
    assert _extract_generated_text({"choices": [{"text": "completion"}]}) == (
        "completion"
    )
    assert _extract_generated_text(
        {"choices": [{"message": {"content": "chat"}}]}
    ) == "chat"
    assert _extract_generated_text(
        {"output": [{"content": [{"type": "output_text", "text": "response"}]}]}
    ) == "response"
