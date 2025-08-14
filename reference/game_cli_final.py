import random
import sys

# === Game State ===
day = 1
gold = 30
beer_stock = 5
tax_day = 30
next_id = 1
max_adventurers = 5
adventurers = []
cost_per_day = 1



def create_adventurer(name=None, role=None):
    global next_id
    names = ["Brom", "Ezren", "Kael", "Lyra", "Nim", "Tarin", "Zara", "Garrick", "Mira", "Thorne", "Elira", "Doran", "Sylas", "Iris", "Raphio"]
    roles = ["Fighter", "Rogue", "Healer", "Mage"]
    if not name:
        name = random.choice(names)
    if not role:
        role = random.choice(roles)

    adv = {
        "id": next_id,
        "name": name,
        "class": role,
        "status": "Ready",
        "recovery": 0
    }

    stats = {
        "strength": random.randint(1, 6),
        "dexterity": random.randint(1, 6),
        "intelligence": random.randint(1, 6),
        "endurance": random.randint(1, 6),
    }

    if role == "Fighter":
        stats["strength"] += 2
        stats["endurance"] += 1
    elif role == "Rogue":
        stats["dexterity"] += 2
    elif role == "Mage":
        stats["intelligence"] += 2
    elif role == "Healer":
        stats["intelligence"] += 1

    adv = {
        "id": next_id,
        "name": name,
        "class": role,
        "status": "Ready",
        "recovery": 0,
        **stats,
        "adventurer_stats": {
        "missions_completed": 0,
        "missions_failed": 0,
        "gold_earned": 0,
        "injuries_sustained": 0,
    }
    }
    
    next_id += 1
    return adv

adventurers.append(create_adventurer("Matchilda", "Rogue"))

missions = [
    {"name": "Clear Slimes", "danger": 1, "reward_range": (5, 10)},
    {"name": "Escort Merchant", "danger": 5, "reward_range": (40, 60), "party_required": True},
    {"name": "Scavenge Herbs in Forest", "danger": 3, "reward_range": (10, 20),"party_required": True},
    {"name": "Defend the Grain Warehouse", "danger": 2, "reward_range": (15, 25), "party_required": True}
]

colors = {
    "RED": "\033[91m",
    "GREEN": "\033[92m",
    "YELLOW": "\033[93m",
    "CYAN": "\033[96m",
    "GOLD": "\033[33m",
    "BEER": "\033[38;5;130m",
    "END": "\033[0m"
}


# === Functions ===

def show_intro():
    tavern_art = r"""
       .    _    +     .  ______   .          .
  (      /|\      .    |      \      .   +
      . |||||     _    | |   | | ||         .
 .      |||||    | |  _| | | | |_||    .
    /\  ||||| .  | | |   | |      |       .
__||||_|||||____| |_|_____________\__________
. |||| |||||  /\   _____      _____  .   .
  |||| ||||| ||||   .   .  .         ________
 . \|`-'|||| ||||    __________       .    .
    \__ |||| ||||      .          .     .
 __    ||||`-'|||  .       .    __________
.    . |||| ___/  ___________             .
   . _ ||||| . _               .   _________
_   ___|||||__  _ \\\\--//    .          _
     _ `---'    .)=\oo|=(.   _   .   .    .
_  ^      .  -    . \._//     .          .
"""
    tutorial = f"""{colors['CYAN']}
Welcome to the Adventurer's Guild Management Game!

You are the guildmaster of a humble tavern where adventurers gather.
Each day, you must manage your resources wisely:
- Recruit adventurers.
- Assign them to missions based on their class.
- Restock beer to attract guests and earn passive gold.
- Try not to run out of money, beer, or adventurers.
- Tax day comes every 30 days! Be ready, it's 60 gold coins ! 

Gold and beer are your lifelines. When you're out of both — it’s over.

Good luck, Guildmaster!
{colors['END']}
"""
    print(tavern_art)
    print(tutorial)
    print("-" * 50 + "\n")

def print_day():
    print(f"\n--- Day {day} ---")
    print(f"{colors['GOLD']}Gold: {gold}{colors['END']} | {colors['BEER']}Beer: {beer_stock}{colors['END']}")
    print(f"{colors['GOLD']}\n[Adventurers]{colors['END']}")
    for i, adv in enumerate(adventurers):
        if adv['status'] == 'Recovering':
            print(f"{i + 1}. {adv['name']} ({adv['class']}) - {adv['status']} ({adv['recovery']}d)")
        else:
            print(f"{i + 1}. {adv['name']} ({adv['class']}) - {adv['status']}")
    print("\n[Missions]")
    for i, m in enumerate(missions):
        party = " (Party)" if m.get("party_required") else ""
        print(f"{i + 1}. {m['name']}{party} (Danger: {m['danger']}) Reward: {m['reward_range'][0]}-{m['reward_range'][1]}g")
    print(f"\n[Options]\n{colors['BEER']}1. Restock Beer{colors['END']}\n{colors['GREEN']}2. Assign Mission{colors['END']}\n{colors['CYAN']}3. End Day{colors['END']}")

def restock_beer():
    global gold, beer_stock
    cost = 5
    if gold >= cost:
        beer_stock += 5
        gold -= cost
        print(colors["CYAN"] + "Beer restocked." + colors["END"])
    else:
        print(colors["RED"] + "Not enough gold to restock beer." + colors["END"])

def assign_mission():
    global gold
    ready_heroes = [a for a in adventurers if a['status'] == 'Ready']
    if not ready_heroes:
        print(colors["YELLOW"] + "No available adventurers." + colors["END"])
        return

    print("Select a mission:")
    for i, m in enumerate(missions):
        party = " (Party)" if m.get("party_required") else ""
        print(f"{i + 1}. {m['name']}{party}")
    try:
        mid = int(input("Mission #: ")) - 1
        mission = missions[mid]
    except:
        print("Invalid input.")
        return

    if mission.get("party_required"):
        print("Select adventurers (comma-separated numbers): \nType 'all' to select all adventurers.")
        for i, a in enumerate(ready_heroes):
            print(f"{i + 1}. {a['name']} (ID: {a['id']})")
        selection = input("Your selection: ").strip().lower()

        if selection == "all":
            party = ready_heroes
        else:
            try:
                indexes = [int(x.strip()) - 1 for x in selection.split(",") if x.strip().isdigit()]
                party = [ready_heroes[i] for i in indexes if 0 <= i < len(ready_heroes)]
            except:
                print("Invalid party selection.")
                return

        if not party:
            print("No valid adventurers selected.")
            return

        outcome = resolve_party_mission(party, mission)
        reward = random.randint(*mission['reward_range'])

        if outcome["success"]:
            gold += reward
            print(colors["GREEN"] + f"Party succeeded! Earned {reward}g." + colors["END"])
            for adv in party:
                for a in adventurers:
                    if a['id'] == adv['id']:
                        a["adventurer_stats"]["missions_completed"] += 1
                        a["adventurer_stats"]["gold_earned"] += reward
                        a['status'] = 'Recovering'
                        a['recovery'] = 1
        else:
            print(colors["RED"] + "Party failed the mission." + colors["END"])
            for adv in party:
                injury_roll = random.randint(1, 6)
                for a in adventurers:
                    if a['id'] == adv['id']:
                        if injury_roll == 1:
                            print(colors["RED"] + f"{a['name']} died on the mission!" + colors["END"])
                            adventurers.remove(a)
                        else:
                            print(colors["YELLOW"] + f"{a['name']} was injured." + colors["END"])
                            a["adventurer_stats"]["injuries_sustained"] += 1
                            a["adventurer_stats"]["missions_failed"] += 1
                            a['status'] = 'Recovering'
                            a['recovery'] = random.randint(2, 5)

    else:
        print("Select an adventurer:")
        for i, a in enumerate(ready_heroes):
            print(f"{i + 1}. {a['name']} (ID: {a['id']})")
        try:
            aid = int(input("Adventurer #: ")) - 1
            adv = ready_heroes[aid]
        except:
            print("Invalid input.")
            return

        outcome = resolve_party_mission([adv], mission)
        reward = random.randint(*mission['reward_range'])

        if outcome["success"]:
            gold += reward
            print(colors["GREEN"] + f"{adv['name']} succeeded! Earned {reward}g." + colors["END"])
            for a in adventurers:
                if a['id'] == adv['id']:
                    a["adventurer_stats"]["missions_completed"] += 1
                    a["adventurer_stats"]["gold_earned"] += reward
                    a['status'] = 'Recovering'
                    a['recovery'] = 1
        else:
            injury_roll = random.randint(1, 6)
            for a in adventurers:
                if a['id'] == adv['id']:
                    if injury_roll == 1:
                        print(colors["RED"] + f"{a['name']} died on the mission!" + colors["END"])
                        adventurers.remove(a)
                    else:
                        print(colors["YELLOW"] + f"{a['name']} was injured." + colors["END"])
                        a["adventurer_stats"]["injuries_sustained"] += 1
                        a["adventurer_stats"]["missions_failed"] += 1
                        a['status'] = 'Recovering'
                        a['recovery'] = random.randint(2, 5)

def resolve_party_mission(party, mission):
    score = 0
    healer_bonus = 0

    for adv in party:
        if adv["class"] == "Fighter":
            score += adv["strength"] + adv["endurance"]
        elif adv["class"] == "Rogue":
            score += adv["dexterity"] + adv["endurance"]
        elif adv["class"] == "Mage":
            score += adv["intelligence"] * 1.5
        elif adv["class"] == "Healer":
            score += adv["intelligence"]
            healer_bonus += 1

    difficulty = mission["danger"] * 10  # Scale it up

    roll = random.randint(1, 6)
    score += roll  # randomness

    print(f"Team Score: {score} vs Danger: {difficulty}")

    if score >= difficulty:
        return {"success": True, "healer_bonus": healer_bonus}
    else:
        return {"success": False, "healer_bonus": healer_bonus}

def select_all_adventurers(ready_heroes):
    return ready_heroes.copy()

def recruit_visitor():
    global gold
    if random.random() < 0.99:
        new_adv = create_adventurer()
        role = new_adv['class']
        
        # Class-based recruitment cost
        cost = 10  # default
        if role == "Rogue":
            cost = 8
        elif role == "Mage":
            cost = 12
        elif role == "Healer":
            cost = 15

        print(colors["CYAN"] + f"A visitor wants to join as a {role} named {new_adv['name']} (ID: {new_adv['id']})." + colors["END"])
        print(colors["GOLD"] + f"Recruitment Cost: {cost}g" + colors["END"])

        if len(adventurers) >= max_adventurers:
            print(colors["RED"] + "Your guild is full. You cannot accept new adventurers right now." + colors["END"])
            return
        
        if gold < cost:
            print(colors["RED"] + f"You need at least {cost} gold to recruit this adventurer." + colors["END"])
            return

        choice = input("Accept? (y/n): ").strip().lower()
        if choice == 'y':
            adventurers.append(new_adv)
            gold -= cost
            print(colors["GREEN"] + f"{new_adv['name']} joined your guild for {cost}g!" + colors["END"])
        else:
            print("You declined the offer.")


def pay_adventurers():
    global gold, adventurers
    total_cost = len(adventurers) * cost_per_day
    if gold >= total_cost:
        gold -= total_cost
        print(colors["GOLD"] + f"Paid {total_cost}g to adventurers." + colors["END"])
    else:
        print(colors["RED"] + "Not enough gold to pay all adventurers! Some are leaving..." + colors["END"])
        affordable = gold // cost_per_day
        if affordable > 0:
            gold -= affordable * cost_per_day
            print(colors["YELLOW"] + f"Paid {affordable} adventurers. The rest have left." + colors["END"])
            adventurers = adventurers[:affordable]
        else:
            print(colors["RED"] + "No gold to pay any adventurers. All have left the guild!" + colors["END"])
            adventurers.clear()



def end_day():
    global day, beer_stock, gold
    day += 1
    if gold <= 0 and not adventurers:
        print(colors["YELLOW"] + "You’re down to nothing but your beer stock. Trying to keep the tavern alive..." + colors["END"])
    if random.random() < 0.45 and beer_stock > 0:
        beer_stock -= 1
        tavern_income = random.randint(1, 3)
        gold += tavern_income
        print(colors["CYAN"] + f"Visitor spent {tavern_income}g." + colors["END"])
        if random.random() < 0.99:
            recruit_visitor()

    pay_adventurers()

    for a in adventurers:
        if a['status'] == 'Recovering':
            a['recovery'] -= 1
            if a['recovery'] <= 0:
                a['status'] = 'Ready'
                a['recovery'] = 0

    if day % tax_day == 0:
        if gold >= 60:
            gold -= 60
            print(colors["CYAN"] + "Paid 60g in taxes." + colors["END"])
        else:
            print(colors["RED"] + "And couldn't pay taxes!" + colors["END"])
            game_over()
            if len(adventurers) == 0:
                game_over()

def recover_from_zero():
    global beer_stock, gold

    if beer_stock <= 0:
        print(colors["RED"] + "You have no adventurers, no beer, and no money. The guild has collapsed." + colors["END"])
        game_over()
        return

    print(colors["CYAN"] + "You open the tavern doors and start selling beer to strangers..." + colors["END"])

    sold = random.randint(1, min(3, beer_stock))  # Sell 1–3 beers
    profit = sold * random.randint(1, 2)          # 1–2g per beer

    beer_stock -= sold
    gold += profit

    print(colors["BEER"] + f"Sold {sold} mugs of beer. Earned {profit}g." + colors["END"])

    if random.random() < 0.5:
        recruit_visitor()


def game_over():
    print(colors["RED"] + "\nYou have no adventurers left and couldn't pay taxes." + colors["END"])
    print(colors["YELLOW"] + "The guild has collapsed.\n" + colors["END"])
    choice = input("Press X to restart, or anything else to quit: ").strip().lower()
    if choice == 'x':
        restart_game()
    else:
        print("Farewell, Guildmaster.")
        sys.exit()

def restart_game():
    global day, gold, beer_stock, tax_day, next_id, adventurers
    day = 1
    gold = 30
    beer_stock = 5
    tax_day = 30
    next_id = 1
    adventurers = [create_adventurer("Brom", "Fighter")]
    max_adventurers = 5
    print(colors["CYAN"] + "\nThe guild has reopened. Good luck!" + colors["END"])

show_intro()
# === Game Loop ===
while True:

    print_day()
    choice = input(f"{colors['RED']}Select option: {colors['END']}")
    if choice == '1':
        restock_beer()
    elif choice == '2':
        assign_mission()
    elif choice in ['3', 'd', 'e']:
        end_day()
    else:
        print("Invalid choice.")