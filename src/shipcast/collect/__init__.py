"""素材を集める collector の登録。"""

from shipcast.collect.base import Collector
from shipcast.collect.git import GitCollector

COLLECTORS: tuple[Collector, ...] = (GitCollector(),)
