extends Control

class Segment:
	var a : Vector2 
	var b : Vector2
	var c : Color
	

func wall(x1,y1,x2,y2) -> Segment:
	var result = Segment.new()
	result.a = Vector2(x1,y1)
	result.b = Vector2(x2,y2)
	result.c = Color.red
	return result


var walls = [

	# Border
	wall(0,0,840,0),
	wall(840,0,840,360),
	wall(840,360,0,360),
	wall(0,360,0,0),
	# Polygon #1
	wall(100,150,120,50),
	wall(120,50,200,80),
	wall(200,80,140,210),
	wall(140,210,100,150),
#	// Polygon #2
	wall(100,200,120,250),
	wall(120,250,60,300),
	wall(60,300,100,200),
#	// Polygon #3
	wall(200,260,220,150),
	wall(220,150,300,200),
	wall(300,200,350,320),
	wall(350,320,200,260),
#	// Polygon #4
	wall(540,60, 560,40),
	wall(560,40,570,70),
	wall(570,70,540,60),
#	// Polygon #5
	wall(650,190,760,170),
	wall(760,170,740,270),
	wall(740,270,630,290),
	wall(630,290,650,190),
#	// Polygon #6
	wall(600,95,780,50),
	wall(780,50,680,150),
	wall(680,150,600,95)
]

var mouse_pos = Vector2(0,0)
var unique_points = []


func hash_vec(v : Vector2) -> String:
	return "%.3f,%.3f" % [v.x, v.y]

var poly_mesh : ArrayMesh = null

# setup
func _ready():
	mouse_pos = screen_size * 0.5
	var seen = {}
	unique_points.clear()
	for seg in walls:
		for p in [seg.a, seg.b]:
			var key = hash_vec(p)
			if not(key in seen):
				seen[key]= true
				unique_points.append( { 'point': p, 'angle':0 } )


func _input(event):
	if event is InputEventKey:
		if event.pressed and event.scancode==KEY_F10:
			get_tree().quit()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	mouse_pos = get_viewport().get_mouse_position()
	if self.get_rect().has_point( mouse_pos ):
		update()


class RayHit:
	var v : Vector2
	var angle : float

	func _init(x,y,rad):
		self.v = Vector2(x,y)
		self.angle = rad

const MaxDistance = 1000

func get_intersect( p1:Vector2, p2:Vector2, p3:Vector2, p4:Vector2 ) -> RayHit:
	var result = Geometry.segment_intersects_segment_2d( p1, p2, p3, p4 )
	if result==null:
		return null
	return RayHit.new( result.x, result.y, result.distance_to( p1 ) )


class SegHit:
	var start: Vector2
	var hit: Vector2
	var dist: float
	var angle: float

	func _init(start, hit, dist):
		self.start = start
		self.hit = hit
		self.dist = dist
		self.angle = (hit-start).angle_to(Vector2(0,1))


func sort_seg_hit( a : SegHit, b :SegHit ) -> bool:
	return true if a.angle < b.angle else false

var visible_triangles = PoolVector3Array()
var visible_coords =    PoolVector2Array()
var triangle_colors =   PoolColorArray()

var screen_size = Vector2(840, 360)

func add_uv(v):
	var sx = v.x / screen_size.x
	var sy = v.y / screen_size.y
	visible_coords.append(Vector2(sx,sy))

func add_tri( v1:Vector2, v2:Vector2, v3:Vector2, col:Color ):
	for it in [v1, v2, v3]:
		add_uv(it)
		triangle_colors.append( col )
		visible_triangles.append( vec3(it, 0) )

func add_sight_polygon(sight : Vector2, col : Color):
	var unique_angles = []
	for p in unique_points:
		var v = p.point
		var angle =atan2( v.y - sight.y, v.x - sight.x )
		p.angle = angle
		unique_angles.append( angle - 0.00001 )
		unique_angles.append( angle )
		unique_angles.append( angle + 0.00001 )
	var intersects = [] # Array of SegHit
	for angle in unique_angles:
		var delta = Vector2( cos(angle), sin(angle) ) * MaxDistance
		var end = sight + delta
		var closest = null
		for seg in walls:
			var hit = Geometry.segment_intersects_segment_2d(sight, end, seg.a, seg.b )
			if not hit:
				continue
			var dist = hit.distance_to(sight)
			if closest==null or dist < closest.dist:
				closest = SegHit.new( sight, hit, dist )
		if closest!=null:
			intersects.push_back( closest )
	intersects.sort_custom(self, 'sort_seg_hit')
	var prev_hit = null
	for i in intersects:
		if prev_hit!=null:
			add_tri( sight, prev_hit, i.hit, col )
		prev_hit = i.hit
	if len(intersects)>2:
		add_tri(sight, prev_hit, intersects[0].hit, col)

func vec3(v:Vector2, z:float) -> Vector3:
	return Vector3(v.x, v.y, z)

func rebuild_mesh():
	if poly_mesh==null:
		poly_mesh = Mesh.new()
		$MeshInstance2D.mesh = poly_mesh
	elif poly_mesh.get_surface_count()==1:
		poly_mesh.surface_remove(0)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	assert len(visible_triangles)%3 == 0
	var n = 0
	for v in visible_triangles:
		var col = triangle_colors[n]
		var c = visible_coords[n]
		n += 1
		st.add_color( col )
		st.add_uv( c )
		st.add_vertex( v )
	st.commit(poly_mesh)
	

const translucent = Color(1.0, 1.0, 1.0, 0.2 )
const delta = PI / 5.0;

func _draw():
	draw_circle( mouse_pos, 5, Color.yellow )	
	visible_triangles.resize(0)
	visible_coords.resize(0)
	triangle_colors.resize(0)
	add_sight_polygon( mouse_pos, Color.black )
	var fuzzy_radius = 4
	var a = 0
	while a <= PI*2.0:
		var rpos = mouse_pos + ( Vector2( cos(a), sin(a) ) * fuzzy_radius )
		a += delta
		add_sight_polygon( rpos, translucent )
	rebuild_mesh()
	for w in walls:
		var d = (w.b - w.a).angle_to( w.a - mouse_pos )
		var color = Color.red if d > 0 else Color.white
		draw_line( w.a, w.b, color, 2 )	














