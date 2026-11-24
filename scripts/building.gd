extends Node2D

var team:int=0
var max_health:int=300
var health:int=300

func take_damage(amount:int)->void:
	health=max(0,health-amount)
	if health<=0: queue_free()
