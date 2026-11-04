"""The blacksmith and the pottery: kit buildings + qprops props (exec'd after qkit, qhouse, qprops, qrough).
Both face -y (Blender) = +Z in Godot, like the houses. Origin = the compound's centre on the ground.
"""
import random


def smithy(into):
    rng = random.Random(21)
    c = coll(into)
    # stone workshop, 6x6, one storey, its own roof chimney off (the forge has the flue)
    house(place, -2.0, 0.0, 6, 6, 1, seed=21, into=into, balcony=False, styles=["stone"], chimney=False)
    # open forge pavilion 4x4 against the workshop's east wall: x 1..5, y -3..1
    for px, py in [(1, -3), (5, -3), (5, 1), (1, 1)]:
        place("Corner_Exterior_Wood", px, py, 0.0, 0, into=into)
    place("Prop_Support", 5.0, -3.0, 0.0, 180, into=into)   # knee braces, reaching into the pavilion
    place("Prop_Support", 5.0, 1.0, 0.0, 0, into=into)
    place("Wall_BottomCover", 3.0, -3.0, 2.95, 0, into=into)
    place("Wall_BottomCover", 3.0, 1.0, 2.95, 180, into=into)
    place("Wall_BottomCover", 5.0, -2.0, 2.95, 90, into=into)
    place("Wall_BottomCover", 5.0, 0.0, 2.95, 90, into=into)
    place("Roof_RoundTiles_4x4", 3.0, -1.0, 3.0, 0, into=into)
    place("Roof_FrontSupports", 3.0, -3.0, 3.0, 0, into=into)
    place("Roof_Front_Brick4", 3.0, 1.0, 3.0, 180, into=into)
    for x in (2.0, 4.0):
        for y in (-2.0, 0.0):
            place("Floor_UnevenBrick", x, y, 0.0, 0, into=into)
    forge(c, (3.1, 0.15, 0.0), roof_top=7.0)
    anvil(c, (2.9, -1.7, 0.0), rot=10)
    barrel(c, (4.35, -0.75, 0.0), name="P_Quench", water=True)
    weapon_rack(c, (1.45, -1.3, 0.0), rot=90)
    grindstone(c, (6.2, -2.4, 0.0), rot=20)
    blob("P_CoalPile", 0.7, 0.45, (4.6, 0.55, 0.0), mat("P_Coal", (0.05, 0.045, 0.045)), c, seed=4)
    place("Prop_Crate", -4.3, -3.9, 0.0, 15, into=into)
    place("Prop_Crate", -3.3, -4.0, 0.0, -10, into=into)
    barrel(c, (-0.9, -3.7, 0.0), name="P_Barrel")


def pottery(into):
    rng = random.Random(33)
    c = coll(into)
    house(place, -2.0, 0.0, 4, 6, 1, seed=33, into=into, balcony=False, styles=["timber"])
    kiln(c, (3.4, 1.4, 0.0), rot=0)
    wheel(c, (1.7, -2.3, 0.0))
    shelf(c, (0.75, 0.0, 0.0), rot=90, length=2.2, rng=random.Random(8))
    for i, (x, y, s) in enumerate([(2.0, -0.7, 0.95), (2.55, -1.05, 0.8), (1.6, -1.1, 0.7)]):
        pot(c, (x, y, 0.0), kind=2, scale=s, color=[None, "cream", None][i], seed=i + 20)
    for i in range(4):
        pot(c, (-0.6 + 0.3 * i, -3.6, 0.0), kind=1, scale=1.0, color="raw" if i % 2 else None, seed=40 + i)
    blob("P_ClayHeap", 0.75, 0.5, (5.0, -1.7, 0.0), mat("P_Clay", (0.48, 0.36, 0.27)), c, seed=9)
    logpile(c, (5.3, 1.8, 0.0))
    place("Prop_Crate", -3.6, -3.8, 0.0, 8, into=into)


def logpile(c, loc):
    import math
    wood = mat("", kit="MI_WoodTrim")
    rng = random.Random(12)
    rows = [(0.0, 4), (0.36, 3), (0.70, 2)]
    for z, n in rows:
        for i in range(n):
            y = (i - (n - 1) / 2) * 0.38
            lg = lathe("P_Log", [(0.0, -0.8), (0.18, -0.8), (0.19, 0.0), (0.18, 0.8), (0.0, 0.8)], (0, 0, 0), wood, c, seg=8, wobble=0.12, seed=rng.randint(0, 99))
            lg.rotation_euler = (0, math.radians(90), math.radians(rng.uniform(-6, 6)))
            lg.location = (loc[0] + rng.uniform(-0.1, 0.1), loc[1] + y, loc[2] + 0.18 + z)
