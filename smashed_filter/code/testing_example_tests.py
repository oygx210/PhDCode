from nose.tools import *


def test_room():
    gold = Room("GoldRoom" ",""This room has gold which you can grab. There's a door to the north""")
    assert_equal(gold.name, "GoldRoom")
    assert_equal(gold.paths, {})
