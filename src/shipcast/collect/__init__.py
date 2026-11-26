"""素材を集める collector の登録。"""

from shipcast.collect.base import Collector
from shipcast.collect.git import GitCollector
from shipcast.collect.specdock import SpecDockCollector

COLLECTORS: tuple[Collector, ...] = (GitCollector(), SpecDockCollector())
