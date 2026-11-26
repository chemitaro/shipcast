from datetime import date

import pytest

from shipcast.model import Neta, Story
from shipcast.neta import NetaSprout
from shipcast.state import Store

DAY = date(2026, 11, 26)
REPO = "demo-app"


def _story(identifier, title, score):
    return Story(identifier, REPO, DAY, title, "見本を作成", "動作を確認", Neta(score))


def test_sprout_at_threshold_lists_at_most_three_escaped_titles(tmp_path):
    with Store(tmp_path) as store:
        sprout = NetaSprout(store, 6)
        store.save_stories(
            [
                _story("numbered", "1. 一番", 1),
                _story("markup", "  <b>x</b> \n & y  ", 2),
                _story("heading", "# 見出し", 2),
            ],
        )
        assert sprout.render(REPO, DAY, (), ()) is None

        store.save_stories([_story("fourth", "四番目", 1)])
        assert sprout.render(REPO, DAY, (), ()) == (
            ":::tip 発信の芽（ネタポイント 6）\n"
            "- &lt;b&gt;x&lt;/b&gt; &amp; y\n"
            "- \\# 見出し\n"
            "- 1\\. 一番\n"
            ":::"
        )


@pytest.mark.parametrize("store_blank_story", [False, True])
def test_sprout_can_have_balance_without_titles(tmp_path, store_blank_story):
    with Store(tmp_path) as store:
        store.add_neta(_story("orphan", "台帳だけの話題", 3))
        second = _story("second", " \t\n ", 3)
        if store_blank_story:
            store.save_stories([second])
        else:
            store.add_neta(second)

        assert NetaSprout(store, 6).render(REPO, DAY, (), ()) == (
            ":::tip 発信の芽（ネタポイント 6）\n:::"
        )
