"""Two-client WoW: Forever test: two whole PBs, each in its own Lua state,
passing their real serialized addon messages to each other.

Both are Forever characters with surnames ("Alpha Stone", "Bravo Reed"), and
every message arrives from "First Surname", as on the client. Alpha has
talked to Mak (Thunder Bluff Leatherworking trainer); Bravo has not. Bravo
syncs with Alpha, asks for Alpha's knowledge after the rev-8 SYNC_DATA, and
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

    def node(name, surname):
        lua = LuaRuntime(unpack_returned_tuples=True)
        g = lua.globals()
        g.PB_BASE = "ProfessionBuddy"
        g.NODE_NAME = name
        g.NODE_SURNAME = surname
        g.print = lambda *a: printed.append(name + ": " + " ".join("" if x is None else str(x) for x in a))
        lua.execute(src)
        return lua

    try:
        A, B = node("Alpha", "Stone"), node("Bravo", "Reed")
        A.execute('TRAINER_OPEN(3008); FLUSH(); TRAINER_CLOSE(); FLUSH()')
        for me, other in ((A, "Bravo Reed-Realm"), (B, "Alpha Stone-Realm")):
            me.execute('ProfBuddyDB.contacts["%s"] = { trusted = true, autoSync = false, lastSync = 0 }' % other)
        B.execute('ProfBuddy.Comm:RequestSync("Alpha Stone-Realm", true); FLUSH()')

        # whispers are addressed to "First Surname"; senders arrive the same way
        nodes = {"Alpha Stone": A, "Bravo Reed": B}
        keys = {id(A): "Alpha Stone", id(B): "Bravo Reed"}
        reversed_chunks = 0
        for _ in range(20):                      # pump until both outboxes stay empty
            moved = False
            for sender in (A, B):
                box = sender.globals().OUTBOX
                batch = [box[i] for i in range(1, len(box) + 1)]
                sender.execute("OUTBOX = {}")
                chunks = [m for m in batch if m.text[:1] == "\x05"]
                if len(chunks) > 1:
                    reversed_chunks += len(chunks)
                for msg in reversed(batch):
                    if msg.target not in nodes:
                        return False, "whisper addressed to %r, not a First Surname" % msg.target
                    if len(msg.text) > 255:
                        return False, "a wire message over 255 bytes"
                    nodes[msg.target].globals().NODE_RECEIVE(msg.prefix, msg.text, msg.dist, keys[id(sender)])
                    moved = True
            if not moved:
                break
        if reversed_chunks == 0:
            return False, "no multi-chunk message crossed, so nothing was delivered out of order"

        types = []
        for node, me in ((A, "A"), (B, "B")):
            got = node.globals().RECEIVED
            for i in range(1, len(got) + 1):
                types.append("%s>%s %s" % ("B" if me == "A" else "A", me, got[i]))
        flow = " ".join(types)
        want = ["B>A SYNC_REQ", "A>B SYNC_DATA", "B>A KNOW_REQ", "A>B KNOW_DATA"]
        missing = [w for w in want if w not in flow]
        if missing:
            return False, "message flow %r lacks %s" % (flow, missing)
        B.execute('''
            local KN = ProfBuddy.Knowledge
            local s = ProfBuddyDB.knowledgeShared and ProfBuddyDB.knowledgeShared["Alpha Stone-Realm"]
            EXPECT(s and s.records[2153] and s.records[2153].teachers[3008], "Bravo did not store Alpha's Mak record")
            EXPECT(KN:LearnLevel(2153) == 15, "Bravo's learn level for Handstitched Leather Pants")
            local tip = table.concat(KN:TooltipLines(2153, "Horde"), " / ")
            EXPECT(tip:find("Mak - Thunder Bluff", 1, true) and tip:find("(from Alpha Stone)", 1, true), "Bravo tooltip: " .. tip)
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
