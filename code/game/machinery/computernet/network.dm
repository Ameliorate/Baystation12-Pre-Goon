/proc/makecomputernets(var/silence = 0)

	if(defer_computernet_rebuild) //Because otherwise explosions will fuck your shit up like never before
		return

	var/netcount = 0
	computernets = list()

	for(var/obj/computercable/C in world)
		C.cnetnum = 0
	for(var/obj/machinery/M in world)
		M.cnetnum = 0
		M.computernet = null
	for(var/obj/machinery/router/R in world)
		R.connectednets = list()
		R.disconnectednets = list()

	for(var/obj/computercable/PC in world)
		if(!PC.cnetnum)
			PC.cnetnum = ++netcount


			world.log << "Starting computernet #[netcount] at [PC.x],[PC.y],[PC.z] ([PC.d1]/[PC.d2])"
			computernet_nextlink_counter = 0
			computernet_nextlink(PC, PC.cnetnum)

	if(DebugN) world.log << "[netcount] computernets found"

	for(var/L = 1 to netcount)
		var/datum/computernet/PN = new()
		computernets += PN
		PN.number = L

	for(var/obj/computercable/C in world)
		var/datum/computernet/PN = computernets[C.cnetnum]
		PN.cables += C

	for(var/obj/machinery/M in world)
		var/list/obj/computercable/AB = M.get_indirect_connectionsCnet()

		var/obj/computercable/A = null
		if(AB.len > 0)
			A = AB[1]
			M.cnetnum = A.cnetnum

	for(var/obj/machinery/M in world)
		if(M.cnetnum && !M.cnetdontadd)
			M.computernet = computernets[M.cnetnum]
			if(!M.computerID)
				world.log << "[M] is not calling its ..() in New()!"
			M.computernet.nodes[M.computerID] = M
			M.computernet.nodes += M //Add both as an association and directly.

			if(M.sniffer)
				M.computernet.sniffers += M

	for(var/obj/computercable/C in world)
		var/list/routers = C.get_routers()
		for(var/obj/machinery/router/R in routers)
			var/datum/computernet/net = computernets[C.cnetnum]
			if (!(R in net.routers))
				net.routers += R
				R.connectednets += net
			if (!(R in net.nodes))
				net.nodes[R.computerID] = R
				net.nodes += R

	for(var/obj/machinery/router/R in world)
		if (R.connectednets.len)
			R.computernet = pick(R.connectednets) //Network discovery can be a fun game!

	for(var/obj/machinery/antenna/base/B in world)
		B.build = 0

	for(var/obj/machinery/antenna/base/Start in world)
		if(!Start.computernet || Start.build) continue
		var/obj/machinery/router/R = new
		R.connectednets += Start.computernet
		Start.computernet.routers += R
		Start.build = 1
		for(var/obj/machinery/antenna/base/OtherR in world)
			if (!OtherR.computernet || OtherR.id != Start.id || OtherR.build)
				continue
			R.connectednets += OtherR.computernet
			OtherR.computernet.routers += R
			OtherR.build = 1


	BuildRoutingTable()

	if (!silence)
		spawn(rand(20, 200))
			for (var/mob/ai/AI in world)
				if (!AI.stat)
					AI << "\red A network reconfiguration has been detected.  You may wish to inform the crew."
	return netcount

// returns a list of all -related objects (nodes, cable, junctions) in turf,
// excluding source, that match the direction d
// if unmarked==1, only return those with cnetnum==0

/proc/computer_list(var/turf/T, var/obj/source, var/d, var/unmarked=0)
	var/list/result = list()

	for(var/obj/computercable/C in T)
		if(!unmarked || !C.cnetnum)
			if (C.d1 == get_dir(T, source.loc) || C.d2 == get_dir(T, source.loc))
				result += C

	result -= source

	return result


/obj/computercable/proc/get_connections()

	var/list/res = list()	// this will be a list of all connected  objects

	var/turf/T = get_step_3d(src, d1)

	res += computer_list(T, src , d1, 1)

	T = get_step_3d(src, d2)

	res += computer_list(T, src, d2, 1)

	return res

/obj/computercable/proc/get_routers()
	var/list/routers = list()
	for(var/obj/machinery/router/R in get_step_3d(src, src.d1))
		routers += R
	for(var/obj/machinery/router/R in get_step_3d(src, src.d2))
		routers += R
	return routers


/obj/machinery/proc/get_connectionsCnet()
	if(!directwiredCnet)
		return get_indirect_connectionsCnet()
	var/obj/computercable/res
	for(var/obj/computercable/C in src.loc)
		if(C.cnetnum > 0)
			res = C
	return res

/obj/machinery/proc/get_indirect_connectionsCnet()
	var/list/res = list()
	for(var/obj/computercable/C in src.loc)

		if(C.cnetnum)
			res += C
	return res

var/computernet_nextlink_counter = 0
var/computernet_nextlink_processing = 0


/proc/computernet_nextlink(var/obj/O, var/num)
	var/list/P

	while(1)
		if( istype(O, /obj/computercable) )
			var/obj/computercable/C = O

			C.cnetnum = num


		if( istype(O, /obj/computercable) )
			var/obj/computercable/C = O

			P = C.get_connections()

		if(P.len == 0)
			return

		O = P[1]


		for(var/L = 2 to P.len)

			computernet_nextlink(P[L], num)

// cut a powernet at this cable object

/datum/computernet/proc/cut_cable(var/obj/computercable/C)

	var/turf/T1 = get_step_3d(C, C.d1)

	var/turf/T2 = get_step_3d(C, C.d2)

	var/list/P1 = computer_list(T1, C, C.d1)	// what joins on to cut cable in dir1

	var/list/P2 = computer_list(T2, C, C.d2)	// what joins on to cut cable in dir2

	if(DebugN)
		for(var/obj/O in P1)
			world.log << "P1: [O] at [O.x] [O.y] : [istype(O, /obj/computercable) ? "[O:d1]/[O:d2]" : null] "
		for(var/obj/O in P2)
			world.log << "P2: [O] at [O.x] [O.y] : [istype(O, /obj/computercable) ? "[O:d1]/[O:d2]" : null] "



	if(P1.len == 0 || P2.len ==0)			// if nothing in either list, then the cable was an endpoint
											// no need to rebuild the powernet, just remove cut cable from the list
		cables -= C
		if(DebugN) world.log << "Was end of cable"
		return

	// zero the cnetnum of all cables & nodes in this powernet

	for(var/obj/computercable/OC in cables)
		OC.cnetnum = 0
	for(var/obj/machinery/OM in nodes)
		OM.cnetnum = 0


	// remove the cut cable from the network
	C.cnetnum = -1
	C.loc = null
	cables -= C



	computernet_nextlink_counter = 0
	computernet_nextlink(P1[1], number)		// propagate network from 1st side of cable, using current cnetnum

	// now test to see if propagation reached to the other side
	// if so, then there's a loop in the network

	var/notlooped = 0
	for(var/obj/O in P2)
		if( istype(O, /obj/machinery) )
			var/obj/machinery/OM = O
			if(OM.cnetnum != number)
				notlooped = 1
				break
		else if( istype(O, /obj/computercable) )
			var/obj/computercable/OC = O
			if(OC.cnetnum != number)
				notlooped = 1
				break

	if(notlooped)

		// not looped, so make a new powernet

		var/datum/computernet/PN = new()
		//PN.tag = "powernet #[L]"
		computernets += PN
		PN.number = computernets.len

		if(DebugN) world.log << "Was not looped: spliting PN#[number] ([cables.len];[nodes.len])"

		for(var/obj/computercable/OC in cables)

			if(!OC.cnetnum)		// non-connected cables will have cnetnum==0, since they weren't reached by propagation

				OC.cnetnum = PN.number
				cables -= OC
				PN.cables += OC		// remove from old network & add to new one

		for(var/obj/machinery/OM in nodes)
			if(!OM.cnetnum)
				OM.cnetnum = PN.number
				OM.computernet = PN
				nodes -= OM
				PN.nodes += OM		// same for  machines

		if(DebugN)
			world.log << "Old PN#[number] : ([cables.len];[nodes.len])"
			world.log << "New PN#[PN.number] : ([PN.cables.len];[PN.nodes.len])"

	else
		if(DebugN)
			world.log << "Was looped."
		//there is a loop, so nothing to be done
		return

	return