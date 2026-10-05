"""Two-client WoW: Forever test: two whole PBs, each in its own Lua state,
passing their real serialized addon messages to each other.

Both are Forever characters with surnames ("Alpha Stone", "Bravo Reed"), on
two connected realms, and
every message arrives from "First Surname", as on the client. Alpha has
talked to Mak (Thunder Bluff Leatherworking trainer); Bravo has not. Bravo
syncs with Alpha, asks for Alpha's knowledge (and skinning loot, rev 11)
after the rev-8 SYNC_DATA, and
ends up with Mak on its Source line, credited to Alpha Stone.

Messages travel as raw addon messages (COMM_REV 9: a long one as numbered
chunks), and every batch a node sends is delivered in REVERSE, as WoW:
Forever can deliver a burst of chunks out of order (m4ru's traces,
2026-09-30).
Called by run_all.py.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
NODE = os.path.join(HERE, "pb_forever_pair.lua")
EXPECT = "FOREVER PAIR TEST PASS"


def run_pair(LuaRuntime, quiet):
    src = open(NODE, encoding="utf-8").read()
    printed = []

    def node(name, surname, realm):
        lua = LuaRuntime(unpack_returned_tuples=True)
        g = lua.globals()
        g.PB_BASE = "ProfessionBuddy"
        g.NODE_NAME = name
        g.NODE_SURNAME = surname
        g.NODE_REALM = realm
        g.print = lambda *a: printed.append(name + ": " + " ".join("" if x is None else str(x) for x in a))
        lua.execute(src)
        return lua

    try:
        # two connected realms, as on the beta (m4ru on Classic Beta PvP, a
        # friend on Classic Beta PvP 2)
        A, B = node("Alpha", "Stone", "Classic Beta PvP"), node("Bravo", "Reed", "Classic Beta PvP 2")
        A.execute('TRAINER_OPEN(3008); FLUSH(); TRAINER_CLOSE(); FLUSH()')
        # Alpha has skinned a Thunder Lizard (3b-3: learned loot is shared)
        A.execute('''ProfBuddy.Knowledge:RecordSkin(3130, { { 2934, 1, "Ruined Leather Scraps", 0 },
                                                         { 2318, 2, "Light Leather", 1 } })
                     ProfBuddy.Knowledge:RecordNode("Copper Vein", "Mining", { { 2770, 1, "Copper Ore", 1 } })''')
        for me, other in ((A, "Bravo Reed"), (B, "Alpha Stone")):
            me.execute('ProfBuddyDB.contacts[ProfBuddy:NormKey("%s")] = { trusted = true, autoSync = false, lastSync = 0 }' % other)
        B.execute('ProfBuddy.Comm:RequestSync("Alpha Stone", true); FLUSH()')

        # whispers are addressed to "First Surname"; senders arrive the same way
        nodes = {"Alpha Stone": A, "Bravo Reed": B}
        keys = {id(A): "Alpha Stone", id(B): "Bravo Reed"}
        state = {"reversed": 0}

        def pump():
            for _ in range(20):                  # until both outboxes stay empty
                moved = False
                for sender in (A, B):
                    box = sender.globals().OUTBOX
                    batch = [box[i] for i in range(1, len(box) + 1)]
                    sender.execute("OUTBOX = {}")
                    chunks = [m for m in batch if m.text[:1] == "\x05"]
                    if len(chunks) > 1:
                        state["reversed"] += len(chunks)
                    for msg in reversed(batch):
                        if msg.target not in nodes:
                            raise AssertionError("whisper addressed to %r, not a First Surname" % msg.target)
                        if len(msg.text) > 255:
                            raise AssertionError("a wire message over 255 bytes")
                        nodes[msg.target].globals().NODE_RECEIVE(msg.prefix, msg.text, msg.dist, keys[id(sender)])
                        moved = True
                if not moved:
                    return

        pump()
        if state["reversed"] == 0:
            return False, "no multi-chunk message crossed, so nothing was delivered out of order"

        # a crafting order across the two realms: Bravo asks Alpha, Alpha
        # accepts and crafts, Bravo confirms
        B.execute('''
            local o = ProfBuddy.Orders:Create({ crafter = ProfBuddy:NormKey("Alpha Stone"),
                item = { id = 2318, name = "Light Leather", profession = "Leatherworking" },
                quantity = 1, matResponsibility = "requester" })
            EXPECT(o, "Bravo could not create the order")
            ORDER_ID = o.id
            ProfBuddy.Comm:SendOrderNew(o)
            FLUSH()
        ''')
        pump()
        oid = B.globals().ORDER_ID
        A.globals().ORDER_ID = oid
        A.execute('''
            local o = ProfBuddyDB.orders[ORDER_ID]
            EXPECT(o and o.status == "pending", "Alpha did not store Bravo's order (refused across realms?)")
            ProfBuddy.Comm:SendOrderUpdate(ProfBuddy.Orders:Accept(ORDER_ID)); FLUSH()
        ''')
        pump()
        A.execute('ProfBuddy.Comm:SendOrderUpdate(ProfBuddy.Orders:MarkCrafted(ORDER_ID)); FLUSH()')
        pump()
        B.execute('''
            local o = ProfBuddyDB.orders[ORDER_ID]
            EXPECT(o and o.status == "crafted" and o.deliveryState == "delivered", "Bravo's order after crafting: "
                   .. tostring(o and o.status) .. " / " .. tostring(o and o.deliveryState))
            ProfBuddy.Comm:SendOrderUpdate(ProfBuddy.Orders:ConfirmReceived(ORDER_ID)); FLUSH()
        ''')
        pump()
        A.execute('''
            EXPECT(ProfBuddyDB.orders[ORDER_ID].status == "completed", "Alpha's order not completed: "
                   .. tostring(ProfBuddyDB.orders[ORDER_ID].status))
        ''')

        types = []
        for node, me in ((A, "A"), (B, "B")):
            got = node.globals().RECEIVED
            for i in range(1, len(got) + 1):
                types.append("%s>%s %s" % ("B" if me == "A" else "A", me, got[i]))
        flow = " ".join(types)
        want = ["B>A SYNC_REQ", "A>B SYNC_DATA", "B>A KNOW_REQ", "A>B KNOW_DATA",
                "B>A ORDER_NEW", "A>B ORDER_ACK", "A>B ORDER_UPDATE", "B>A ORDER_UPDATE"]
        missing = [w for w in want if w not in flow]
        if missing:
            return False, "message flow %r lacks %s" % (flow, missing)
        B.execute('''
            local KN = ProfBuddy.Knowledge
            local s = ProfBuddyDB.knowledgeShared and ProfBuddyDB.knowledgeShared[ProfBuddy:NormKey("Alpha Stone")]
            EXPECT(s and s.records[2153] and s.records[2153].teachers[3008], "Bravo did not store Alpha's Mak record")
            EXPECT(KN:LearnLevel(2153) == 15, "Bravo's learn level for Handstitched Leather Pants")
            local tip = table.concat(KN:TooltipLines(2153, "Horde"), " / ")
            EXPECT(tip:find("Mak - Thunder Bluff", 1, true) and tip:find("(from Alpha Stone)", 1, true), "Bravo tooltip: " .. tip)
            EXPECT(ProfBuddyDB.knowledge == nil or ProfBuddyDB.knowledge[2153] == nil, "Alpha's record landed in Bravo's own store")
            local l = s.loot and s.loot[3130]
            EXPECT(l and l.n == 1 and l.items[2318] and l.items[2318].max == 2 and l.items[2934].c == 1,
                   "Bravo did not store Alpha's skinning loot")
            EXPECT(ProfBuddyDB.skinLoot == nil, "Alpha's skins landed in Bravo's own store")
            local g = s.nodeLoot and s.nodeLoot["Copper Vein"]
            EXPECT(g and g.n == 1 and g.prof == "Mining" and g.items[2770], "Bravo did not store Alpha's Copper Vein")
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
