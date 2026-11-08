extends SceneTree
var failed:=false
var checks:=0
var arena
var a
var e
func _initialize() -> void:run.call_deferred()
func frames(n: int) -> void:
 for i in n:await process_frame
func check(ok: bool,label: String) -> void:
 checks+=1;failed=failed or not ok;print(("PASS " if ok else "FAIL ")+label)
func setup_hearts() -> Array:
 a.reset();e.clear_hazards();arena.forms.get_child(2).position=Vector3.ZERO
 arena.player.position=Vector3(0,0,8);arena.dash_remaining=0;e.player_health=100;e.player_hit_grace=0
 a.begin_attack("vision_charm");a._process(1.41)
 var hearts: Array=a.projectiles.duplicate()
 for heart in hearts:heart.set_process(false)
 return hearts
func run() -> void:
 change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"));await scene_changed;await frames(3)
 arena=current_scene;a=arena.attacks;e=arena.encounter
 e.start_encounter();a.set_process(false);arena.set_physics_process(false);e.set_process(false);arena.presentation.set_process(false)
 arena.set_phase(3);a.set_process(false)
 a.begin_attack("vision_charm");a._process(1.30)
 check(a.projectiles.is_empty() and a.vision_remaining==0,"P3 heart anticipation cannot charm or launch early")
 a._process(.11)
 check(a.projectiles.size()==4 and a.vision_remaining==0,"P3 releases exactly four hearts and no instant sector charm")
 var headings: Array=[];var types:=true
 for heart in a.projectiles:
  heart.set_process(false);headings.append(heart.direction)
  types=types and heart.get_script()==load("res://Scripts/Qingqiu/charm_heart_projectile.gd")
 check(types and headings[0]!=headings[1] and headings[2]!=headings[3],"Four actual charm projectiles have separate fan directions")
 check(is_instance_valid(a.beacon) and e.hazards.size()==9 and e.fire_beats.size()==2,"Cleansing light and P3's three-beat pillar accompaniment remain connected")
 var hearts:=setup_hearts();var heart=hearts[1]
 arena.player.position=heart.position+heart.direction*3.0
 var hp: float=e.player_health;heart._process(.55);a.update_vision(.1)
 check(a.vision_remaining>float(e.phase_config["charm_seconds"])-.2 and a.vision_rect.visible,"Swept heart contact applies actual vision obstruction")
 check(e.player_health==hp and arena.charm_remaining==0,"Heart charm causes no HP damage or forced walking")
 arena.player.position=a.beacon.position;a.update_vision(.02);a.update_vision(.3)
 check(a.vision_remaining==0 and not a.vision_rect.visible,"The existing light pickup still clears heart-inflicted charm")
 hearts=setup_hearts();heart=hearts[1];arena.player.position=heart.position+heart.direction*3.0;arena.dash_remaining=.2
 heart._process(.55);check(a.vision_remaining==0 and heart.resolved,"Dashing through a heart avoids charm and consumes that contact")
 hearts=setup_hearts();arena.player.position=Vector3(-10,0,10)
 for shot in hearts:shot._process(1.0)
 check(a.vision_remaining==0,"Moving out of the four flight lanes avoids charm")
 hearts=setup_hearts();heart=hearts[0];arena.player.position=Vector3(19,0,-19);heart._process(7)
 check(heart.resolved and heart.is_queued_for_deletion(),"Heart lifetime/out-of-field cleanup does not leave stray projectiles")
 a.reset();e.clear_hazards()
 var attacks: Dictionary={1:["cub_swipe","cub_charge","cub_feint","cub_tail_sweep","cub_charm"],2:["barrage_fan","barrage_ring","barrage_weave","p2_claw_gale","p2_tail_crescent","p2_fox_roar"],3:["vision_charm","p3_spiral"]}
 for phase in [1,2,3]:
  arena.set_phase(phase);a.set_process(false);var rig=a.rig();rig.set_process(false)
  for attack in attacks[phase]:
   a.reset();e.clear_hazards();arena.player.position=Vector3(0,0,8)
   var triggers: int=rig.attack_tail.triggers;a.begin_attack(attack)
   check(rig.attack_tail.active and rig.attack_tail.triggers==triggers+1,"P%d %s triggers its own tail anticipation"%[phase,attack])
   var left: int=rig.skeleton.find_bone("eye_left");var eye_before: Transform3D=rig.skeleton.get_bone_pose(left)
   rig._process(.16);rig._process(.12)
   var expected: int=[8,16,72][phase-1]
   check(rig.attack_tail.offsets.size()==expected,"P%d %s drives every segment of every existing tail"%[phase,attack])
   var first: int=rig.tail_bones[0];var last: int=rig.tail_bones[7]
   check(rig.attack_tail.offsets[first].angle_to(Quaternion.IDENTITY)>.005 and not rig.attack_tail.offsets[first].is_equal_approx(rig.attack_tail.offsets[last]),"P%d %s has visible root-to-tip follow-through"%[phase,attack])
   check(rig.skeleton.get_bone_pose(left).is_equal_approx(eye_before),"P%d %s tail overlay leaves eye registration intact"%[phase,attack])
   a.resolve_attack();rig._process(.43)
   check(not rig.attack_tail.active and rig.attack_tail.offsets.is_empty(),"P%d %s tail recoil settles after release"%[phase,attack])
   a.reset();await frames(1)
 arena.set_phase(2);a.reset();a.begin_attack("barrage_fan")
 var tail=a.rig().attack_tail;var prior: int=tail.triggers
 a.resolve_attack();a._process(.41);a._process(.41)
 check(tail.triggers==prior+3,"Each of P2's three actual volleys adds a tail recoil beat")
 a.reset();arena.set_phase(3);a.begin_attack("p3_spiral");a._process(1);a._process(1.36)
 tail=a.rig().attack_tail;prior=tail.triggers
 a._process(.61);a._process(4.91)
 check(a.spiral_round==8 and tail.triggers==prior+8,"Each of P3's eight actual spiral rounds adds a tail recoil beat")
 arena.set_phase(3);setup_hearts();e.start_encounter()
 check(a.projectiles.is_empty() and a.vision_remaining==0,"Restart removes all four hearts and their charm state")
 var clean:=true
 for form in arena.forms.get_children():clean=clean and not form.get_node("FoxRig").attack_tail.active and form.get_node("FoxRig").attack_tail.offsets.is_empty()
 check(clean,"Restart removes every phase's additive tail pose")
 print("CHARM_HEARTS_TAIL %d checks; passed=%s"%[checks,not failed])
 arena.queue_free();current_scene=null;await frames(4);quit(int(failed))
