from importlib.metadata import version


def test_package_exposes_installed_version():
    from shipcast import __version__

    assert __version__ == version("shipcast")
