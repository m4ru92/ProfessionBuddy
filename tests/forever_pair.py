"""Two-client WoW: Forever test: two whole PBs, each in its own Lua state,
passing their real serialized addon messages to each other.

Alpha has talked to Mak (Thunder Bluff Leatherworking trainer); Bravo has
not. Bravo syncs with Alpha, asks for Alpha's knowledge after the rev-8
SYNC_DATA, and ends up with Mak on its Source line, credited to Alpha.
Called by run_all.py.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
NODE = os.path.join(HERE, "pb_forever_pair.lua")
EXPECT = "FOREVER PAIR TEST PASS"


def run_pair(LuaRuntime, quiet):
    src = open(NODE, encoding="utf-8").read()
    printed = []

    def node(name):
        lua = LuaRuntime(unpack_returned_tuples=True)
        g = lua.globals()
        g.PB_BASE = "ProfessionBuddy"
        g.NODE_NAME = name
        g.print = lambda *a: printed.append(name + ": " + " ".join("" if x is None else str(x) for x in a))
        lua.execute(src)
        return lua

    try:
        A, B = node("Alpha"), node("Bravo")
        A.execute('TRAINER_OPEN(3008); FLUSH(); TRAINER_CLOSE(); FLUSH()')
        for me, other in ((A, "Bravo-Realm"), (B, "Alpha-Realm")):
            me.execute('ProfBuddyDB.contacts["%s"] = { trusted = true, autoSync = false, lastSync = 0 }' % other)
        B.execute('ProfBuddy.Comm:RequestSync("Alpha-Realm", true); FLUSH()')

        types = []
        nodes = {"Alpha-Realm": A, "Bravo-Realm": B}
        keys = {id(A): "Alpha-Realm", id(B): "Bravo-Realm"}
        for _ in range(20):                      # pump until both outboxes stay empty
            moved = False
            for sender in (A, B):
                box = sender.globals().OUTBOX
                while len(box) > 0:
                    msg = box[1]
                    sender.execute("table.remove(OUTBOX, 1)")
                    target = nodes[msg.target + "-Realm" if "-" not in msg.target else msg.target]
                    types.append("%s>%s %s" % (keys[id(sender)][0], keys[id(target)][0],
                                               sender.globals().NODE_TYPE(msg.text)))
                    target.globals().NODE_RECEIVE(msg.prefix, msg.text, msg.dist, keys[id(sender)])
                    moved = True
            if not moved:
                break

        flow = " ".join(types)
        want = ["B>A SYNC_REQ", "A>B SYNC_DATA", "B>A KNOW_REQ", "A>B KNOW_DATA"]
        missing = [w for w in want if w not in flow]
        if missing:
            return False, "message flow %r lacks %s" % (flow, missing)
        B.execute('''
            local KN = ProfBuddy.Knowledge
            local s = ProfBuddyDB.knowledgeShared and ProfBuddyDB.knowledgeShared["Alpha-Realm"]
            EXPECT(s and s.records[2153] and s.records[2153].teachers[3008], "Bravo did not store Alpha's Mak record")
            EXPECT(KN:LearnLevel(2153) == 15, "Bravo's learn level for Handstitched Leather Pants")
            local tip = table.concat(KN:TooltipLines(2153, "Horde"), " / ")
            EXPECT(tip:find("Mak - Thunder Bluff", 1, true) and tip:find("(from Alpha)", 1, true), "Bravo tooltip: " .. tip)
            EXPECT(ProfBuddyDB.knowledge == nil or ProfBuddyDB.knowledge[2153] == nil, "Alpha's record landed in Bravo's own store")
        ''')
        A.execute('''
            EXPECT(ProfBuddyDB.knowledgeShared == nil, "Alpha stored knowledge it never asked for")
        ''')
        if not quiet:
            print("    flow: " + flow)
        printed.append(EXPECT + ": " + flow)
    except Exception as e:                       # noqa: BLE001
        if quiet:
            for line in printed[-8:]:
                print("    " + line)
        msg = str(e).strip()
        return False, (msg.splitlines()[-1] if msg else repr(e))
    return True, EXPECT
