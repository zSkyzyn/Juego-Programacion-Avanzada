extends CharacterBody2D

# --- ENUMERADOR PARA LA MÁQUINA DE ESTADOS (FSM) ---
enum State { GROUNDED, CHARGING, JUMPING, FALLING }
var current_state: State = State.GROUNDED

# --- CONFIGURACIÓN DE FÍSICAS DETERMINISTAS ---
const SPEED = 130.0
const GRAVITY = 1100.0
const WALL_BOUNCE_FORCE = 0.65

const MIN_JUMP_FORCE = 180.0
const MAX_JUMP_FORCE = 580.0
const JUMP_CHARGE_SPEED = 650.0

# --- VARIABLES DE CONTROL ---
var jump_charge: float = 0.0
var jump_direction: float = 0.0

func _physics_process(delta: float) -> void:
	# 1. Aplicar Gravedad según el estado
	if current_state == State.JUMPING or current_state == State.FALLING:
		velocity.y += GRAVITY * delta

	# 2. Ejecutar el comportamiento del estado actual
	_process_state(delta)

	# 3. Aplicar movimiento cinemático exacto (Píxel Perfect)
	var collided = move_and_slide()
	
	# 4. Manejar colisiones externas (Rebotes)
	if collided and is_on_wall() and not is_on_floor():
		_handle_wall_bounce()
		
	# 5. Transiciones de estado globales
	_check_state_transitions()

# --- PROCESAMIENTO DE LOS ESTADOS ---
func _process_state(delta: float) -> void:
	var move_input = Input.get_axis("ui_left", "ui_right")
	
	match current_state:
		State.GROUNDED:
			# Caminar normalmente por el suelo
			if move_input != 0:
				velocity.x = move_input * SPEED
			else:
				velocity.x = move_toward(velocity.x, 0, SPEED)
			
			# Transición a Carga de Salto
			if Input.is_action_just_pressed("ui_accept"):
				_change_state(State.CHARGING)
				jump_direction = move_input # Bloquea la dirección inicial

		State.CHARGING:
			# No hay movimiento horizontal mientras carga
			velocity.x = 0
			jump_charge = min(jump_charge + JUMP_CHARGE_SPEED * delta, MAX_JUMP_FORCE)
			
			# Al soltar, se calcula la parábola matemática de despegue
			if Input.is_action_just_released("ui_accept"):
				_execute_jump()

		State.JUMPING:
			# Impulsado estrictamente por inercia en el aire (Pérdida de control)
			if velocity.y >= 0:
				_change_state(State.FALLING)

		State.FALLING:
			# Cayendo por gravedad, sin control aéreo
			pass

# --- CAMBIO DE ESTADO Y ENCAPSULAMIENTO ---
func _change_state(new_state: State) -> void:
	current_state = new_state
	# Aquí se pueden disparar animaciones más adelante (ej: Sprite2D.play("charging"))

# --- EJECUCIÓN DEL SALTO CUANTIFICADO ---
func _execute_jump() -> void:
	velocity.y = -max(jump_charge, MIN_JUMP_FORCE)
	velocity.x = jump_direction * (SPEED * 1.25)
	
	jump_charge = 0.0
	_change_state(State.JUMPING)

# --- REBOTE EN PAREDES (FÍSICA ESTRICTA) ---
func _handle_wall_bounce() -> void:
	velocity.x = -velocity.x * WALL_BOUNCE_FORCE
	# Mantiene el estado de JUMPING o FALLING pero invierte el vector X

# --- VERIFICACIÓN DE TRANSICIONES SÓLIDAS ---
func _check_state_transitions() -> void:
	# Si toca el suelo y estaba en el aire, vuelve a GROUNDED
	if is_on_floor() and (current_state == State.JUMPING or current_state == State.FALLING):
		velocity.x = 0
		_change_state(State.GROUNDED)
	
	# Si camina de una plataforma al vacío sin saltar
	if not is_on_floor() and current_state == State.GROUNDED:
		_change_state(State.FALLING)
