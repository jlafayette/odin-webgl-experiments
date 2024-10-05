package trails

import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:math/rand"
import "core:slice"

Particle :: struct {
	pos:   glm.vec2,
	vel:   glm.vec2,
	color: glm.vec4,
	scale: f32,
	life:  f32,
}
ParticleEmitter :: struct {
	particles:        []Particle,
	rate_per_second:  int,
	last_used:        int,
	matrices:         []glm.mat4,
	colors:           []glm.vec4,
	carry_over_time:  f32,
	starting_colors:  []glm.vec4,
	starting_color_i: int,
	pos:              glm.vec2,
	vel:              glm.vec2,
}
LIFE :: 2
PARTICLES_PER_SECOND :: 800
N_PARTICLES :: LIFE * PARTICLES_PER_SECOND + 200
SCALE :: 1
SCALE_R :: 16
RANDOM_MAGNITUDE :: 120
DAMPING_AMOUNT :: 0.99
GRAVITY :: -30_000

particle_emitter_init :: proc(e: ^ParticleEmitter) {
	e.particles = make([]Particle, N_PARTICLES)
	e.matrices = make([]glm.mat4, N_PARTICLES)
	e.colors = make([]glm.vec4, N_PARTICLES)
	e.rate_per_second = PARTICLES_PER_SECOND
	e.starting_colors = make([]glm.vec4, 100)
	for &c in e.starting_colors {
		r := 0.5 + (rand.float32() * 0.5)
		g := 0.5 + (rand.float32() * 0.5)
		b := 0.5 + (rand.float32() * 0.5)
		c = {r, g, b, 1}
	}
}
particle_emitter_destroy :: proc(e: ^ParticleEmitter) {
	delete(e.particles)
}
particle_emitter_update :: proc(e: ^ParticleEmitter, dt: f32, pos: glm.vec2, raw_vel: glm.vec2) {
	decay := dt / LIFE
	for &p, i in e.particles {
		if p.life > 0 {
			p.life -= decay
			// position += velocity * delta + acceleration * delta * delta * 0.5			
			acc: glm.vec2 = {0, GRAVITY}
			p.pos += p.vel * dt + acc * dt * dt * 0.5

			p.vel *= DAMPING_AMOUNT

			p.color.a = math.clamp(0, 1, 1.0 - math.pow(1 - p.life, 2.0))
		} else {
			p.color.a = 0
		}
	}
	if dt > 0.018 {
		fmt.printf("dt: %.3f\n", dt)
	}
	new_count: int = cast(int)math.round((f32(e.rate_per_second) * dt) + e.carry_over_time)
	e.carry_over_time += dt
	if new_count > 0 {
		e.carry_over_time = 0
	}

	old_pos := e.pos
	e.pos = pos
	old_vel := e.vel
	vel := raw_vel * 600 * dt
	e.vel = vel

	// interpolate between old_pos -> pos for new particle position
	pos_vec := (old_pos - pos) / f32(math.max(new_count, 1))
	pos_vec = old_pos - pos

	for i in 0 ..< new_count {
		p_index, ok := particle_find_unused(e)
		if !ok {break}
		if e.starting_color_i >= len(e.starting_colors) {
			e.starting_color_i = 0
		}
		col := e.starting_colors[e.starting_color_i]
		// percentage of old and new vel assigned randomly
		new_percent := rand.float32()
		old_percent := 1 - new_percent
		v0 := old_vel * old_percent
		v1 := e.vel * new_percent
		new_p := particle_respawn(pos + (pos_vec * rand.float32()), v0 + v1, col)
		new_p.life += 0.01 * f32(i)
		e.particles[p_index] = new_p
		e.starting_color_i += 1
	}

	// sort particles by life so tranparency works correctly
	slice.sort_by(e.particles, less_fn)
	e.last_used = 0 // reset since sorting messes with everything

	// update matrices and colors for instance buffer updates
	for p, i in e.particles {
		e.matrices[i] = glm.mat4Translate({p.pos.x, p.pos.y, p.life})
		e.matrices[i] *= glm.mat4Scale(p.scale)
		e.colors[i] = p.color
	}
}

less_fn :: proc(i, j: Particle) -> bool {
	return i.life < j.life
}

@(private = "file")
particle_find_unused :: proc(e: ^ParticleEmitter) -> (int, bool) {
	for i := e.last_used; i < len(e.particles); i += 1 {
		if e.particles[i].life <= 0 {
			e.last_used = i
			return i, true
		}
	}
	for i := 0; i < e.last_used; i += 1 {
		if e.particles[i].life <= 0 {
			e.last_used = i
			return i, true
		}
	}
	fmt.println("e0")
	e.last_used = 0
	return 0, false
}
@(private = "file")
particle_respawn :: proc(pos: glm.vec2, vel: glm.vec2, col: glm.vec4) -> Particle {
	p: Particle
	{
		angle := rand.float32() * math.TAU
		mag: f32 = rand.float32() * RANDOM_MAGNITUDE
		random_vel: glm.vec2 = {math.sin(angle), math.cos(angle)} * mag
		p.vel = vel + random_vel + {0, 250}
	}
	p.pos = pos
	p.color = col
	p.scale = SCALE + (rand.float32() * SCALE_R)
	p.life = 1
	return p
}

