extends SceneTree
## Native comparison fixture. Run this same absolute script with --path set
## to either the untouched game or work_positions_candidate. It issues real
## orders and a paid placement; it never writes actor positions or checkpoints.
## --fixture-fast-forward completes ordinary fixed-step simulation headlessly.
var g: Node
var workers: Array = []
var house: Dictionary = {}
var phase := "assemble"
var finished := false
var phase_ticks := 0
func _initialize(): call_deferred("run")
func run():
	var campaign=root.get_node("Campaign")
	campaign.current=0;campaign.launch=true;campaign.resume=false;campaign.muted=true
	g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g
	workers=g.units.filter(func(w):return w.kind=="worker")
	g.camera_focus=Vector3(-4,0,17);g.camera.size=29
	# One normal move order per actor makes a repeatable common staging point.
	# Individual orders legitimately share a destination in both versions.
	for worker in workers:
		g.selected=[worker];g.command_at(Vector3(2,0,17))
	g.selected=workers;g.update_selection()
	print("WORK_POSITION_REVIEW: ordinary individual moves, then a paid six-worker house; no actor repositioning or free resources.")
	if "--fixture-fast-forward" in OS.get_cmdline_user_args():
		g.set_process(false)
		for i in 1600:
			g.advance_simulation_time(0.05)
			advance_fixture()
			if finished:break
		quit(0 if finished else 1)
func _process(_delta: float) -> bool:
	if is_instance_valid(g) and not finished:advance_fixture()
	return false
func advance_fixture():
	phase_ticks+=1
	if phase=="assemble" and workers.all(func(w):return w.task=="idle"):
		g.selected=workers;g.set_build("house")
		if not g.place_building(Vector3(-4,0,19)):
			push_error("Fixture paid placement failed; "+g.placement_issue("house",Vector3(-4,0,19)))
			finished=true;quit(2);return
		house=g.buildings.back();phase="build";phase_ticks=0
		print("WORK_POSITION_REVIEW_STAGING ",workers.map(func(w):return w.node.position))
	elif phase=="build" and house.built>=1 and workers.all(func(w):return w.task=="idle"):
		finished=true;g.paused=true;g.selected=workers;g.update_selection()
		g.notify("6人で建設完了：一人ずつクリックして選択を確認",30)
		var positions := {}
		for worker in workers:positions[worker.node.position]=true
		print("WORK_POSITION_REVIEW_COMPLETE unique_positions=",positions.size()," positions=",workers.map(func(w):return w.node.position))
