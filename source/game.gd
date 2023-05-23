extends Node2D



var deck: Deck
var players: Array = []
var fields: Array = []

var my_turn:= false
var player_index: int



func _ready() -> void:
	if multiplayer.is_server():
		Lobby.player_loaded()
	else:
		Lobby.player_loaded.rpc_id(1)


# Called only on the server.
func start_game() -> void:
	create_fields.rpc(Lobby.players)
	
	deck = Deck.new()
	for player in players:
		for i in range(8):
			draw_card(player)
	
	var id = players[randi_range(0, players.size() - 1)].id
	if id == 1:
		set_turn(true)
	else:
		set_turn.rpc_id(id, true)


@rpc
func set_turn(turn: bool) -> void:
	my_turn = turn
	for button in $Buttons.get_children():
		button.disabled = not turn


@rpc("call_local")
func create_fields(lobby_players_info: Dictionary) -> void:
	var keys = lobby_players_info.keys()
	keys.sort() # Need to make sure this array is the same on all clients.
	var table_radius: float = $Table.RADIUS
	var table_position: Vector2 = $Table.position
	for index in keys.size():
		var id = keys[index]
		if id == multiplayer.get_unique_id():
			player_index = index
		var field: Field = load("res://source/field.tscn").instantiate()
		var fraction:= (index as float) / keys.size() as float
		field.position = table_position + Vector2.from_angle(TAU * fraction) * table_radius * 0.5 
		add_child(field)
		field.player_name =  lobby_players_info[id]["name"]
		field.look_at(table_position)
		field.rotation += PI / 2
		fields.push_back(field)
		
		# This is here so that players and fields array have the same order on the server
		if multiplayer.is_server():
			players.push_back(Player.new(id, Lobby.players[id]["name"]))
			Lobby.players[id]["index"] = index


func draw_card(player: Player) -> void:
	var card:= deck.draw()
	player.hand.push_back(card)
	var card_info:= {"color": card.color, "shape": card.shape}
	if player.id == 1:
		$Hand.add_card(card_info)
	else:
		$Hand.add_card.rpc_id(player.id, card_info)


@rpc("any_peer")
func play_from_hand(index_in_hand: int) -> void:
	var acting_player_index: int
	if multiplayer.get_remote_sender_id() == 0:
		acting_player_index = 0
		$Hand.remove_card(index_in_hand)
	else:
		acting_player_index = Lobby.players[multiplayer.get_remote_sender_id()]["index"]
		$Hand.remove_card.rpc_id(multiplayer.get_remote_sender_id(), index_in_hand)
	
	var card: Card = players[acting_player_index].hand[index_in_hand]
	play_card.rpc({"color": card.color, "shape": card.shape}, acting_player_index)
	players[acting_player_index].hand.erase(card)


@rpc("call_local")
func play_card(card_info: Dictionary, field_index: int) -> void:
	var card:= HandCard.new(Card.new(card_info["color"], card_info["shape"]))
	var field = fields[field_index]
	var row = field.front_row
	var index = row.find(null)
	row[index] = card
	card.draggable = false
	card.position = field.to_global(field.zone_positions[index] + field.zone_size / 2)
	card.scale = Vector2(0.4, 0.4)
	card.rotation = field.rotation
	add_child(card)


func _on_card_placed(hand_card: HandCard, placement_position: Vector2) -> void:
	if placement_position.distance_to($Table.position) < $Table.RADIUS:
		if multiplayer.is_server():
			play_from_hand($Hand.cards.find(hand_card))
		else:
			play_from_hand.rpc_id(1, $Hand.cards.find(hand_card))


func _on_left_button_pressed() -> void:
	if my_turn:
		if multiplayer.is_server():
			action_push_left()
		else:
			action_push_left.rpc_id(1)


@rpc("any_peer")
func action_push_left() -> void:
	pass


func _on_right_button_pressed() -> void:
	if my_turn:
		if multiplayer.is_server():
			action_push_right()
		else:
			action_push_right.rpc_id(1)


@rpc("any_peer")
func action_push_right() -> void:
	pass


func _on_swap_button_pressed() -> void:
	if my_turn:
		if multiplayer.is_server():
			action_swap()
		else:
			action_swap.rpc_id(1)


@rpc("any_peer")
func action_swap() -> void:
	pass


func _on_take_button_pressed() -> void:
	if my_turn:
		if multiplayer.is_server():
			action_take()
		else:
			action_take.rpc_id(1)


@rpc("any_peer")
func action_take() -> void:
	pass
