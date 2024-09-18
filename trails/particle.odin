package trails

import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:math/rand"

Particle :: struct {
	pos:   glm.vec2,
	vel:   glm.vec2,
	color: glm.vec4,
	scale: f32,
	life:  f32,
}
ParticleEmitter :: struct {
	particles:        #soa[]Particle,
	rate_per_second:  int,
	last_used:        int,
	matrices:         []glm.mat4,
	colors:           []glm.vec4,
	carry_over_time:  f32,
	starting_colors:  []glm.vec4,
	starting_color_i: int,
}
particle_emitter_init :: proc(e: ^ParticleEmitter, max: int, rate_per_second: int) {
	e.particles = make(#soa[]Particle, max)
	e.matrices = make([]glm.mat4, max)
	e.colors = make([]glm.vec4, max)
	e.rate_per_second = rate_per_second
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
particle_emitter_update :: proc(e: ^ParticleEmitter, dt: f32) {
	for &p, i in e.particles {
		p.life -= dt
		if p.life > 0 {
			// position += velocity * delta + acceleration * delta * delta * 0.5			
			acc: glm.vec2 = {0, -10_000}
			// v0 := p.vel
			// v1 := v0 * a * dt
			p.pos += p.vel * dt + acc * dt * dt * 0.5

			// p.pos += p.vel * dt
			p.color.a -= dt * 1.5
		} else {
			p.color.rgb = {0, 0, 0}
		}
	}
	if dt > 0.017 {
		fmt.printf("dt: %.3f\n", dt)
	}
	new_count: int = cast(int)math.round((f32(e.rate_per_second) * dt) + e.carry_over_time)
	e.carry_over_time += dt
	if new_count > 0 {
		e.carry_over_time = 0
	}

	for i in 0 ..< new_count {
		p_index, ok := particle_find_unused(e)
		if !ok {break}
		if e.starting_color_i >= len(e.starting_colors) {
			e.starting_color_i = 0
		}
		c := e.starting_colors[e.starting_color_i]
		new_p := particle_respawn(c)
		e.particles[p_index] = new_p
		e.starting_color_i += 1
		// e.particles[p_index].pos = new_p.pos
		// e.particles[p_index].vel = new_p.vel
		// e.particles[p_index].color = new_p.color
		// e.particles[p_index].scale = new_p.scale
		// e.particles[p_index].life = new_p.life
	}
	// update matrices and colors for instance buffer updates
	for p, i in e.particles {
		e.matrices[i] = glm.mat4Translate({p.pos.x, p.pos.y, 0})
		e.matrices[i] *= glm.mat4Scale(p.scale)
		e.colors[i] = p.color
	}
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
particle_respawn :: proc(c: glm.vec4) -> Particle {
	p: Particle

	{
		angle := rand.float32() * math.TAU
		mag: f32
		mag = rand.float32()
		mag *= 100
		p.vel = {math.sin(angle), math.cos(angle)} * mag
	}
	{
		x := rand.float32()
		y := rand.float32()
		p.pos = {(x * 640) - 320, (y * 480) - 210}
	}

	{
		// r := 0.5 + (rand.float32() * 0.5)
		// g := 0.5 + (rand.float32() * 0.5)
		// b := 0.5 + (rand.float32() * 0.5)
		// p.color = {r, g, b, 1}
		p.color = c
	}

	r_scale := 4 + (rand.float32() * 4)
	p.scale = r_scale

	p.life = 4
	return p
}

