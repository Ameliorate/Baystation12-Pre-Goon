/mob/human/say(message as text)
	message = copytext(sanitize(message), 1, MAX_MESSAGE_LEN)
	if(!message)
		return
	world.log_say("[src.name]/[src.key] : [message]")

	if (src.muted)
		return
	var/sentmessage = null	//stupid fix
	var/alt_name
	if (src.name != src.rname)
		if(src.wear_id && src.wear_id.registered)
			alt_name = " (as [src.wear_id.registered])"
		else
			alt_name = " (as Unknown)"
	if (src.dead())
		for(var/mob/M in world)
			if (M.dead())
				M << text("<B>[]</B>[] []: []", src.rname, alt_name, (src.stat > 1 ? "\[<I>dead</I> \]" : ""), message)
		return
	if(!src.awake())
		return
	if (copytext(message, 1, 2) == "*" && src.awake())
		src.emote(copytext(message, 2, length(message) + 1))
		return

	if(src.sdisabilities & 2)
		return

	if ((!( message ) || istype(src.wear_mask, /obj/item/weapon/clothing/mask/muzzle)))
		return

	if (src.awake() || src.stat > 1)

		var/list/L = list(  )
		var/italics = 0
		var/obj_range = null

		if (findtext(message, ";") == 1) //say it into headset - just uses a ;, because it's the most common use case
			//say "; words" or say ";words"

			message = copytext(message, 2, length(message) + 1)
			if(src.stuttering)
				sentmessage = stutter(message)
			else
				sentmessage = message
			if (src.w_radio)
				src.w_radio.talk_into(usr, sentmessage)
			L += hearers(1,src)
			obj_range = 1
			italics = 1

		else if (findtext(message, ":r") == 1) //say into right hand - say ":r words" or say ":rwords"

			message = copytext(message, 3, length(message) + 1)
			if(src.stuttering)
				sentmessage = stutter(message)
			else
				sentmessage = message
			if (src.r_hand)
				src.r_hand.talk_into(usr, sentmessage)
			L += hearers(1,src)
			obj_range = 1
			italics = 1
		else if (findtext(message, ":l") == 1) // left hand

			message = copytext(message, 3, length(message) + 1)
			if(src.stuttering)
				sentmessage = stutter(message)
			else
				sentmessage = message
			if (src.l_hand)
				src.l_hand.talk_into(usr, sentmessage)
			L += hearers(1,src)
			obj_range = 1
			italics = 1
		else if (findtext(message, ":w") == 1) //whisper

			message = copytext(message, 3, length(sentmessage) + 1)
			if(src.stuttering)
				sentmessage = stutter(message)
			else
				sentmessage = message
			L += hearers(1,src)
			obj_range = 1
			italics = 1
		else if (findtext(message, ":i") == 1)

			message = copytext(message, 3, length(sentmessage) + 1)
			if(src.stuttering)
				sentmessage = stutter(message)
			else
				sentmessage = message
			for(var/obj/item/weapon/radio/intercom/I in view(1,src))
				I.talk_into(usr, message)
			L += hearers(1,src)
			obj_range = 1
			italics = 1

		else
			L += hearers(src)
			obj_range = 7

		L -= src
		L += src
		var/turf/T = src.loc
		if (locate(/obj/move, T))
			T = locate(/obj/move, T)
		if(src.stuttering)	sentmessage = stutter(message)
		else	sentmessage = message
		if (italics)
			sentmessage = text("<I>[]</I>", sentmessage)
		if (src.zombie)
			for(var/mob/M in L)
				if (istype(M, src.type) && (M.zombie))
					M.show_message(text("<B>[src.rname]</B>: [sentmessage]"), 6)
				else if (!M.zombie)
					var/zombiespeak = ""
					zombiespeak = pick(zombiesay)
					M.show_message(text("<B>Unknown</B>:[zombiespeak]", ),6)
			for(var/obj/O in view(obj_range, null))
				spawn( 0 )
				if (O)
					O.hear_talk(usr, sentmessage)
					break
			return
		if (((src.oxygen && src.oxygen.icon_state == "oxy0") || (!( (istype(T, /turf) || istype(T, /obj/move)) ) || T.oxygen > 0)))
			for(var/mob/M in L)
				if (istype(src.wear_mask, /obj/item/weapon/clothing/mask/voicemask))
					M.show_message(text("<B>[src.name]</B>: [message]"), 6, "<B>[src]</B> moves \his mouth.", 1)
				else if (istype(M, src.type) && (!M.zombie) || istype(M, /mob/ai) || istype(M, /mob/observer))
					M.show_message(text("<B>[]</B>[]: []", src.rname, alt_name, sentmessage), 6, "<B>[src]</B> moves \his mouth.", 1)
				else if (istype(M, src.type) && (M.zombie))
					if(!(src.key == M.key))
						M.show_message(text("The human: []", stars(sentmessage)), 6, "The human moves its mouth.", 1)
		for(var/obj/O in view(obj_range, null))
			spawn( 0 )
			if (O)
				O.hear_talk(usr, sentmessage)
				break
	//for(var/mob/M in world)
	//	if (M.stat > 1)
	//		M << text("<B>[]</B>[] []: []", src.rname, alt_name, (src.stat > 1 ? "\[<I>dead</I> \]" : ""), sentmessage)
	return
