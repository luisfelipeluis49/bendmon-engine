import Base
import ./model.bend as Model
import ./rng.bend as Rng
import ./combat_math.bend as Math
import ./combat_resolver.bend as Combat
import ./roster.bend as Roster
import ./sources.bend as Sources
import ./scheduler.bend as Scheduler
import ./driver.bend as Driver
import ./reducer.bend as Reducer
import ./participants.bend as Participants
import ./effects.bend as Effects
import ./multi_type.bend as Multi

# This file is the narrow runtime boundary for the current M3 battle slice.
# It owns runtime snapshots and RNG transactions while Scheduler, Driver and
# Combat remain the authorities for validation, event order and branch draws.
type SourceReservation is Data:
  SourceReservation{source: Model.ActorId, move: Math.MoveId, target: Model.ActorId}

type CombatProfile is Data:
  CombatProfile{
    mode: Math.AccuracyMode,
    attacker_accuracy: Math.Stage,
    target_evasion: Math.Stage,
    power: U32,
    level: U32,
    attack: U32,
    defense: U32,
    critical_bonus: U32
  }

type ActionSnapshot is Data:
  ActionSnapshot{
    reservation: SourceReservation,
    profile: CombatProfile,
    rng: Rng.RngState
  }

type DefenderSnapshot is Data:
  DefenderSnapshot{target: Model.ActorId, profile: CombatProfile}

# Lowered command payload only. The public mixing.runtime entry point creates
# this after Eligibility.plan; it contains no pre-reserved source list.
type RuntimeMixPlan is Data:
  RuntimeMixPlan{individual: Nat, recipe_id: Nat, result_id: Nat, first: Math.MoveId,
    second: Math.MoveId, first_cooldown: U32, second_cooldown: U32,
    program: Effects.EffectProgram, components: List<&2, Multi.TypeId>}

type RuntimeMixWitness is Data:
  # actor maps the immutable individual/current-move battle snapshot to its
  # live scheduler actor. active/conscious fields are ignored on input and
  # recomputed when execution begins.
  RuntimeMixWitness{individual: Nat, actor: Model.ActorId, active: Bool,
    conscious: Bool, current_moves: List<&2, Math.MoveId>}

def witness_actor_id(witness: RuntimeMixWitness) -> Model.ActorId:
  match witness:
    case RuntimeMixWitness{individual, actor, active, conscious, moves}:
      actor

def RuntimeMixWitness.le(left: RuntimeMixWitness,
  right: RuntimeMixWitness) -> Bool:
  Model.ActorId.le(witness_actor_id(left), witness_actor_id(right))

type EncounterKind is Data:
  WildEncounter{}
  TrainerEncounter{}
  BossEncounter{}
  LockedEncounter{}

type QueuedReservation is Data:
  QueuedMove{
    sequence: Nat,
    reservation: SourceReservation,
    attacker: CombatProfile
  }
  QueuedEffectMove{
    sequence: Nat,
    reservation: SourceReservation,
    attacker: CombatProfile,
    recoil: Nat,
    program: Effects.EffectProgram,
    snapshot: Effects.ActionSnapshot
  }
  QueuedMixedMove{
    sequence: Nat,
    reservation: SourceReservation,
    second_source: Math.MoveId,
    attacker: CombatProfile,
    recoil: Nat,
    plan: RuntimeMixPlan,
    actor_types: List<&2, Multi.TypeId>,
    target_types: List<&2, Multi.TypeId>,
    witnesses: List<&2, RuntimeMixWitness>,
    snapshot: Effects.ActionSnapshot
  }
  QueuedSwitch{sequence: Nat, source: Model.ActorId, incoming: Model.ActorId}
  QueuedEscape{
    sequence: Nat,
    source: Model.ActorId,
    player_speed: U32,
    enemy_speed: U32
  }

type RuntimeEffectState is Data:
  RuntimeEffectState{
    source: Model.ActorId,
    target: Model.ActorId,
    world: Effects.EffectWorld
  }

type RuntimeState is Data:
  RuntimeState{
    battle: Model.BattleState,
    rng: Rng.RngState,
    encounter: EncounterKind,
    failed_escapes: U32,
    sources: List<&2, Sources.MoveSource>,
    reservations: List<&2, QueuedReservation>,
    trapped: List<&2, Model.ActorId>,
    defenders: List<&2, DefenderSnapshot>,
    effects: Maybe<&2, RuntimeEffectState>
  }

type RuntimeCommand is Data:
  RuntimeMove{
    source: Model.ActorId,
    target: Model.ActorId,
    move: Math.MoveId,
    windup: U32,
    recovery: U32,
    cooldown: U32,
    priority: Nat,
    recoil: Nat,
    attacker: CombatProfile
  }
  RuntimeEffectMove{
    source: Model.ActorId,
    target: Model.ActorId,
    move: Math.MoveId,
    windup: U32,
    recovery: U32,
    cooldown: U32,
    priority: Nat,
    recoil: Nat,
    attacker: CombatProfile,
    program: Effects.EffectProgram,
    snapshot: Effects.ActionSnapshot
  }
  RuntimeMixedMove{
    source: Model.ActorId,
    target: Model.ActorId,
    windup: U32,
    recovery: U32,
    priority: Nat,
    recoil: Nat,
    attacker: CombatProfile,
    plan: RuntimeMixPlan,
    actor_types: List<&2, Multi.TypeId>,
    target_types: List<&2, Multi.TypeId>,
    witnesses: List<&2, RuntimeMixWitness>,
    snapshot: Effects.ActionSnapshot
  }
  RuntimeWait{source: Model.ActorId}
  RuntimeSwitch{source: Model.ActorId, incoming: Model.ActorId}
  RuntimeEscape{source: Model.ActorId}

# M4's production action boundary. The scheduler supplies its accepted snapshot
# and execution-time world, then commits this pure atomic result alongside its
# normal cooldown/recovery transition. apply_aftermath is false only when the
# runtime has already established battle completion for the action.
def runtime_effect_attempt(program: Effects.EffectProgram,
  world: Effects.EffectWorld, snapshot: Effects.ActionSnapshot,
  rng: Rng.RngState, apply_aftermath: Bool) -> Effects.EffectResult:
  Effects.attempt(program, world, snapshot, rng, apply_aftermath)

def RuntimeCommand.actor(command: RuntimeCommand) -> Model.ActorId:
  match command:
    case RuntimeMove{source, target, move, windup, recovery, cooldown, priority,
        recoil, attacker}:
      source
    case RuntimeEffectMove{source, target, move, windup, recovery, cooldown,
        priority, recoil, attacker, program, snapshot}:
      source
    case RuntimeMixedMove{source, target, windup, recovery, priority, recoil,
        attacker, plan, actor_types, target_types, witnesses, snapshot}:
      source
    case RuntimeWait{source}:
      source
    case RuntimeSwitch{source, incoming}:
      source
    case RuntimeEscape{+source}:
      source

def RuntimeCommand.le(left: RuntimeCommand, right: RuntimeCommand) -> Bool:
  Model.ActorId.le(RuntimeCommand.actor(left), RuntimeCommand.actor(right))

def runtime_model_command(command: RuntimeCommand) -> Model.Command:
  match command:
    case RuntimeMove{source, target, move, windup, recovery, cooldown, priority,
        recoil, attacker}:
      Model.BattleMove{source, target, windup, recovery, cooldown, priority,
        0n, recoil}
    case RuntimeEffectMove{source, target, move, windup, recovery, cooldown,
        priority, recoil, attacker, program, snapshot}:
      Model.BattleMove{source, target, windup, recovery, cooldown, priority,
        0n, recoil}
    case RuntimeMixedMove{source, target, windup, recovery, priority, recoil,
        attacker, plan, actor_types, target_types, witnesses, snapshot}:
      match plan:
        case RuntimeMixPlan{individual, recipe_id, result_id, first, second,
            first_cooldown, second_cooldown, program, components}:
          # This cooldown only satisfies the shared scheduler contract. The
          # authoritative M6 cooldowns are atomically charged on both sources.
          Model.BattleMove{source, target, windup, recovery,
            U32.max(first_cooldown, second_cooldown), priority, 0n, recoil}
    case RuntimeWait{source}:
      Model.BattleWait{source}
    case RuntimeSwitch{source, incoming}:
      Model.BattleUtility{source, incoming, 0, 30, 0n}
    case RuntimeEscape{+source}:
      Model.BattleUtility{source, source, 0, 30, 0n}

def runtime_model_commands(
  commands: List<&2, RuntimeCommand>
) -> List<&2, Model.Command>:
  match commands:
    case Nil{}:
      Nil{}
    case command <> +rest:
      runtime_model_command(command) <> runtime_model_commands(rest)

def runtime_source_requests(
  commands: List<&2, RuntimeCommand>
) -> List<&2, Sources.SourceRequest>:
  match commands:
    case Nil{}:
      Nil{}
    case RuntimeMove{source, target, move, windup, recovery, cooldown,
        priority, recoil, attacker} <> rest:
      Sources.SourceRequest{source, move} <> runtime_source_requests(rest)
    case RuntimeEffectMove{source, target, move, windup, recovery, cooldown,
        priority, recoil, attacker, program, snapshot} <> rest:
      Sources.SourceRequest{source, move} <> runtime_source_requests(rest)
    case RuntimeMixedMove{+source, target, windup, recovery, priority, recoil,
        attacker, plan, actor_types, target_types, witnesses, snapshot} <> rest:
      match plan:
        case RuntimeMixPlan{individual, recipe_id, result_id, first, second,
            first_cooldown, second_cooldown, program, components}:
          Sources.SourceRequest{source, first} <>
            Sources.SourceRequest{source, second} <>
            runtime_source_requests(rest)
    case command <> rest:
      runtime_source_requests(rest)

def command_source_used(
  +wanted: Model.ActorId, commands: List<&2, RuntimeCommand>
) -> Bool:
  match commands:
    case Nil{}:
      False{}
    case command <> rest:
      Bool.or(Model.ActorId.eq(wanted, RuntimeCommand.actor(command)),
        command_source_used(wanted, rest))

def duplicate_runtime_source(
  commands: List<&2, RuntimeCommand>, found: Bool
) -> Bool:
  match commands:
    case Nil{}:
      found
    case command <> +rest:
      match found:
        case True{}:
          True{}
        case False{}:
          duplicate_runtime_source(rest,
            command_source_used(RuntimeCommand.actor(command), rest))

def canonical_physical_state(burned: Bool) -> Effects.PhysicalDamageState:
  match burned:
    case True{}: Effects.BurnedPhysical{}
    case False{}: Effects.NormalPhysical{}

def canonical_effect_snapshot_status(
  +values: List<&2, Effects.StatusInstance>,
  snapshot: Effects.ActionSnapshot
) -> Effects.ActionSnapshot:
  match snapshot:
    case Effects.ActionSnapshot{level, physical_attack, special_attack,
        accuracy, accuracy_mode, physical_damage, critical_bonus}:
      Effects.ActionSnapshot{level, physical_attack, special_attack,
        Effects.accuracy_after_status(accuracy, values), accuracy_mode,
        canonical_physical_state(Effects.status_present(Effects.Burn{}, values)),
        critical_bonus}

def canonical_effect_snapshot(
  world: Effects.EffectWorld, snapshot: Effects.ActionSnapshot
) -> Effects.ActionSnapshot:
  match world:
    case Effects.EffectWorld{source, target}:
      canonical_effect_snapshot_status(Effects.actor_statuses(source), snapshot)

def queued_effect_snapshot(
  effects: Maybe<&2, RuntimeEffectState>, snapshot: Effects.ActionSnapshot
) -> Effects.ActionSnapshot:
  match effects:
    case None{}:
      snapshot
    case Some{RuntimeEffectState{source, target, world}}:
      canonical_effect_snapshot(world, snapshot)

def append_reservations(
  commands: List<&2, RuntimeCommand>, +sequence: Nat,
  +player_speed: U32, +enemy_speed: U32,
  out: List<&2, QueuedReservation>,
  +effects: Maybe<&2, RuntimeEffectState>
) -> List<&2, QueuedReservation>:
  match commands:
    case Nil{}:
      out
    case command <> rest:
      match command:
        case RuntimeMove{source, +target, move, windup, recovery, cooldown,
            priority, recoil, attacker}:
          QueuedMove{sequence, SourceReservation{source, move, target},
            attacker} <>
            append_reservations(rest, 1n+sequence, player_speed, enemy_speed,
              out, effects)
        case RuntimeEffectMove{source, +target, move, windup, recovery,
            cooldown, priority, recoil, attacker, program, snapshot}:
          QueuedEffectMove{sequence,
            SourceReservation{source, move, target}, attacker, recoil, program,
            queued_effect_snapshot(effects, snapshot)} <>
            append_reservations(rest, 1n+sequence, player_speed, enemy_speed,
              out, effects)
        case RuntimeMixedMove{source, +target, windup, recovery, priority,
            recoil, attacker, +plan, actor_types, target_types, witnesses,
            snapshot}:
          match plan:
            case RuntimeMixPlan{individual, recipe_id, result_id, first, +second,
                first_cooldown, second_cooldown, program, components}:
              QueuedMixedMove{sequence,
                SourceReservation{source, first, target}, second, attacker,
                recoil, plan, actor_types, target_types, witnesses,
                queued_effect_snapshot(effects, snapshot)} <>
                append_reservations(rest, 1n+sequence, player_speed,
                  enemy_speed, out, effects)
        case RuntimeSwitch{source, incoming}:
          QueuedSwitch{sequence, source, incoming} <>
            append_reservations(rest, 1n+sequence, player_speed, enemy_speed,
              out, effects)
        case RuntimeEscape{source}:
          QueuedEscape{sequence, source, player_speed, enemy_speed} <>
            append_reservations(rest, 1n+sequence, player_speed, enemy_speed,
              out, effects)
        case RuntimeWait{source}:
          append_reservations(rest, 1n+sequence, player_speed, enemy_speed,
            out, effects)

type RuntimeEvent is Data:
  RuntimeMiss{source: Model.ActorId, target: Model.ActorId, draw: U32}
  RuntimeNoDamage{source: Model.ActorId, target: Model.ActorId, critical: Bool}
  RuntimeHit{source: Model.ActorId, target: Model.ActorId, damage: U32, critical: Bool}
  RuntimeFizzle{source: Model.ActorId, target: Model.ActorId}
  RuntimeCancel{source: Model.ActorId, target: Model.ActorId}
  RuntimeEffectsCommitted{events: List<&2, Effects.EffectEvent>}
  RuntimeMixEffectsCommitted{sequence: Nat, recipe_id: Nat,
    individual: Nat,
    witnesses: List<&2, RuntimeMixWitness>,
    events: List<&2, Effects.EffectEvent>,
    status_state_changed: Bool}

type ActionResult is Data:
  ActionCommitted{rng: Rng.RngState, event: RuntimeEvent}
  ActionFizzled{rng: Rng.RngState, event: RuntimeEvent}
  ActionCancelled{rng: Rng.RngState, event: RuntimeEvent}
  ActionFault{rng: Rng.RngState, reason: Rng.RngSampleResult}

def miss_event(reservation: SourceReservation, +draw: U32) -> RuntimeEvent:
  match reservation:
    case SourceReservation{source, move, target}:
      RuntimeMiss{source, target, draw}

def no_damage_event(reservation: SourceReservation, critical: Bool) -> RuntimeEvent:
  match reservation:
    case SourceReservation{source, move, target}:
      RuntimeNoDamage{source, target, critical}

def hit_event(
  reservation: SourceReservation, +damage: U32, critical: Bool
) -> RuntimeEvent:
  match reservation:
    case SourceReservation{source, move, target}:
      RuntimeHit{source, target, damage, critical}

def fizzle_event(reservation: SourceReservation) -> RuntimeEvent:
  match reservation:
    case SourceReservation{source, move, target}:
      RuntimeFizzle{source, target}

def cancel_event(reservation: SourceReservation) -> RuntimeEvent:
  match reservation:
    case SourceReservation{source, move, target}:
      RuntimeCancel{source, target}

def resolve_outcome(
  reservation: SourceReservation, +original: Rng.RngState,
  result: Combat.CombatResolution
) -> ActionResult:
  match result:
    case Combat.CombatResolved{+rng, outcome}:
      match outcome:
        case Combat.CombatMiss{draw, accuracy_candidates}:
          ActionCommitted{rng, miss_event(reservation, draw)}
        case Combat.CombatEffect{accuracy_candidates}:
          ActionCommitted{rng, no_damage_event(reservation, False{})}
        case Combat.CombatImmune{accuracy_candidates}:
          ActionCommitted{rng, no_damage_event(reservation, False{})}
        case Combat.CombatNoDamage{critical, critical_draw,
            accuracy_candidates, critical_candidates}:
          ActionCommitted{rng, no_damage_event(reservation, critical)}
        case Combat.CombatHit{damage, critical, critical_draw,
            accuracy_candidates, critical_candidates}:
          ActionCommitted{rng, hit_event(reservation, damage, critical)}
    case Combat.CombatInvalid{rng}:
      ActionFizzled{original, fizzle_event(reservation)}
    case Combat.CombatRngFault{rng, reason}:
      ActionFault{original, reason}

def resolve_profile(
  reservation: SourceReservation, +rng: Rng.RngState,
  profile: CombatProfile
) -> ActionResult:
  match profile:
    case CombatProfile{mode, attacker_accuracy, target_evasion, +power, +level,
        +attack, +defense, +critical_bonus}:
      resolve_outcome(reservation, rng,
        Combat.resolve(rng, mode, attacker_accuracy, target_evasion, power,
          level, attack, defense, critical_bonus))

def resolve_action(snapshot: ActionSnapshot) -> ActionResult:
  match snapshot:
    case ActionSnapshot{reservation, profile, +rng}:
      resolve_profile(reservation, rng, profile)

type EscapeResult is Data:
  EscapeSucceeded{rng: Rng.RngState}
  EscapeFailed{rng: Rng.RngState, failed_attempts: U32}
  EscapeUnavailable{rng: Rng.RngState, failed_attempts: U32}
  EscapeRejected{rng: Rng.RngState, failed_attempts: U32}

def escape_decide(
  hit: Bool, +next_rng: Rng.RngState, +failed: U32
) -> EscapeResult:
  match hit:
    case True{}:
      EscapeSucceeded{next_rng}
    case False{}:
      EscapeFailed{next_rng, U32.add(failed, 1)}

def escape_sample(
  kind: EncounterKind, +rng: Rng.RngState, +failed: U32, +chance: U32,
  sample: Rng.RngSampleResult
) -> EscapeResult:
  match kind:
    case TrainerEncounter{}:
      EscapeUnavailable{rng, failed}
    case BossEncounter{}:
      EscapeUnavailable{rng, failed}
    case LockedEncounter{}:
      EscapeUnavailable{rng, failed}
    case WildEncounter{}:
      match sample:
        case Rng.RngSampled{+next_rng, +draw, candidates}:
          escape_decide(U32.is_lt(draw, chance), next_rng, failed)
        case _:
          EscapeRejected{rng, failed}

def escape_attempt(
  kind: EncounterKind, +rng: Rng.RngState, +failed: U32,
  +player_speed: U32, +enemy_speed: U32
) -> EscapeResult:
  +chance = Roster.escape_chance(player_speed, enemy_speed, failed)
  escape_sample(kind, rng, failed, chance, Rng.sample(rng, 10000))

def has_trainer_escape(
  commands: List<&2, RuntimeCommand>
) -> Bool:
  match commands:
    case Nil{}:
      False{}
    case RuntimeEscape{source} <> rest:
      True{}
    case command <> rest:
      has_trainer_escape(rest)

def trainer_kind(kind: EncounterKind) -> Bool:
  match kind:
    case TrainerEncounter{}:
      True{}
    case BossEncounter{}:
      True{}
    case LockedEncounter{}:
      True{}
    case WildEncounter{}:
      False{}

def trapped_actor(
  +wanted: Model.ActorId, trapped: List<&2, Model.ActorId>
) -> Bool:
  match trapped:
    case Nil{}:
      False{}
    case +actor <> rest:
      Bool.or(Model.ActorId.eq(wanted, actor), trapped_actor(wanted, rest))

def mode_ok(mode: Math.AccuracyMode, accuracy: Math.Stage) -> Bool:
  match mode:
    case Math.AlwaysHit{}:
      Math.stage_ok(accuracy)
    case Math.OrdinaryAccuracy{+base}:
      Bool.and(Bool.and(U32.is_ge(base, 500), U32.is_le(base, 10000)),
        Math.stage_ok(accuracy))

def attacker_profile_ok(profile: CombatProfile) -> Bool:
  match profile:
    case CombatProfile{mode, accuracy, evasion, +power, +level, +attack,
        defense, critical_bonus}:
      Bool.and(mode_ok(mode, accuracy),
        Bool.and(Bool.and(U32.is_ge(power, 1), U32.is_le(power, 200)),
          Bool.and(Bool.and(U32.is_ge(level, 1), U32.is_le(level, 200)),
            Bool.and(U32.is_ge(attack, 1), U32.is_le(attack, 9999)))))

def defender_profile_ok(profile: CombatProfile) -> Bool:
  match profile:
    case CombatProfile{mode, accuracy, evasion, power, level, attack,
        +defense, critical_bonus}:
      Bool.and(Math.stage_ok(evasion),
        Bool.and(U32.is_ge(defense, 1), U32.is_le(defense, 9999)))

def defender_found_ok(found: Maybe<&2, CombatProfile>) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{profile}:
      defender_profile_ok(profile)

def switch_actor_values(out_actor: Model.Actor, in_actor: Model.Actor) -> Bool:
  match out_actor in_actor:
    case Model.Actor{out_id, out_side, out_hp, out_speed, out_phase, out_cd}
        Model.Actor{in_id, in_side, 0n, in_speed, in_phase, in_cd}:
      False{}
    case Model.Actor{out_id, out_side, out_hp, out_speed, out_phase, out_cd}
        Model.Actor{in_id, in_side, 1n+in_hp, in_speed, Model.Benched{}, in_cd}:
      Participants.same_side(out_side, in_side)
    case _ _:
      False{}

def switch_found_ok(
  outgoing: Maybe<&2, Model.Actor>, incoming: Maybe<&2, Model.Actor>
) -> Bool:
  match outgoing incoming:
    case Some{out_actor} Some{in_actor}:
      switch_actor_values(out_actor, in_actor)
    case _ _:
      False{}

def precheck_defender_put(
  equal: Bool, profile: CombatProfile, fallback: Maybe<&2, CombatProfile>
) -> Maybe<&2, CombatProfile>:
  match equal:
    case True{}:
      Some{profile}
    case False{}:
      fallback

def precheck_find_defender(
  +target: Model.ActorId, defenders: List<&2, DefenderSnapshot>
) -> Maybe<&2, CombatProfile>:
  match defenders:
    case Nil{}:
      None{}
    case DefenderSnapshot{+actor, profile} <> rest:
      precheck_defender_put(Model.ActorId.eq(target, actor), profile,
        precheck_find_defender(target, rest))

def effect_state_matches(
  source: Model.ActorId, target: Model.ActorId,
  effects: Maybe<&2, RuntimeEffectState>
) -> Bool:
  match effects:
    case None{}:
      False{}
    case Some{RuntimeEffectState{effect_source, effect_target, world}}:
      Bool.and(Model.ActorId.eq(source, effect_source),
        Model.ActorId.eq(target, effect_target))

def runtime_actor_le(left: Model.Actor, right: Model.Actor) -> Bool:
  match left right:
    case Model.Actor{left_id, left_side, left_hp, left_speed, left_phase,
        left_cooldown}
         Model.Actor{right_id, right_side, right_hp, right_speed, right_phase,
        right_cooldown}:
      Model.ActorId.le(left_id, right_id)

def runtime_mix_actor_active(phase: Model.Phase) -> Bool:
  match phase:
    case Model.Benched{}: False{}
    case Model.Defeated{}: False{}
    case _: True{}

def runtime_mix_witness_eligibility(active: Bool, conscious: Bool,
  witness: RuntimeMixWitness) -> List<&2, RuntimeMixWitness>:
  match active conscious:
    case True{} True{}:
      match witness:
        case RuntimeMixWitness{individual, actor, old_active, old_conscious,
            current_moves}:
          [RuntimeMixWitness{individual, actor, True{}, True{}, current_moves}]
    case _ _:
      Nil{}

def runtime_actor_id(actor: Model.Actor) -> Model.ActorId:
  match actor:
    case Model.Actor{id, side, hp, speed, phase, cooldown}: id

def runtime_mix_witness_live_status(witness: RuntimeMixWitness,
  active: Bool, conscious: Bool) -> List<&2, RuntimeMixWitness>:
  runtime_mix_witness_eligibility(active, conscious, witness)

def runtime_mix_witness_live(witness: RuntimeMixWitness,
  actor: Model.Actor) -> List<&2, RuntimeMixWitness>:
  match witness actor:
    case RuntimeMixWitness{individual, witness_actor, old_active,
        old_conscious, current_moves}
         Model.Actor{actor_id, side, 0n, speed, phase, cooldown}:
      runtime_mix_witness_live_status(witness,
        runtime_mix_actor_active(phase), False{})
    case RuntimeMixWitness{individual, witness_actor, old_active,
        old_conscious, current_moves}
         Model.Actor{actor_id, side, 1n+hp, speed, phase, cooldown}:
      runtime_mix_witness_live_status(witness,
        runtime_mix_actor_active(phase), True{})

def runtime_mix_witnesses_live(witnesses: List<&2, RuntimeMixWitness>,
  actors: List<&2, Model.Actor>) -> List<&2, RuntimeMixWitness>:
  match witnesses actors:
    case witness <> witness_rest actor <> actor_rest:
      List.append(&2, RuntimeMixWitness, runtime_mix_witness_live(witness, actor),
        runtime_mix_witnesses_live(witness_rest, actor_rest))
    case _ _:
      Nil{}

def runtime_witness_roster_matches(witnesses: List<&2, RuntimeMixWitness>,
  actors: List<&2, Model.Actor>) -> Bool:
  match witnesses actors:
    case witness <> witness_rest Model.Actor{id, side, hp, speed, phase,
        cooldown} <> actor_rest:
      Bool.and(Model.ActorId.eq(witness_actor_id(witness), id),
        runtime_witness_roster_matches(witness_rest, actor_rest))
    case Nil{} Nil{}: True{}
    case _ _: False{}

def runtime_witness_roster_valid(witnesses: List<&2, RuntimeMixWitness>,
  actors: List<&2, Model.Actor>) -> Bool:
  +sorted_actors = {List.sort(~Model.Actor, ~runtime_actor_le,
    actors) : List<&2, Model.Actor>}
  runtime_witness_roster_matches(witnesses, sorted_actors)


def runtime_command_in_state(
  command: RuntimeCommand, +battle: Model.BattleState,
  trapped: List<&2, Model.ActorId>,
  defenders: List<&2, DefenderSnapshot>,
  effects: Maybe<&2, RuntimeEffectState>
) -> Bool:
  match command:
    case RuntimeWait{source}:
      True{}
    case RuntimeEscape{source}:
      True{}
    case RuntimeMove{source, +target, move, windup, recovery, cooldown,
        priority, recoil, attacker}:
      Bool.and(attacker_profile_ok(attacker),
        defender_found_ok(precheck_find_defender(target, defenders)))
    case RuntimeEffectMove{source, +target, move, windup, recovery, cooldown,
        priority, recoil, attacker, program, snapshot}:
      Bool.and(Bool.and(attacker_profile_ok(attacker),
          defender_found_ok(precheck_find_defender(target, defenders))),
        effect_state_matches(source, target, effects))
    case RuntimeMixedMove{source, +target, windup, recovery, priority, recoil,
        attacker, plan, actor_types, target_types, witnesses, snapshot}:
      Bool.and(Bool.and(Bool.and(attacker_profile_ok(attacker),
          defender_found_ok(precheck_find_defender(target, defenders))),
        effect_state_matches(source, target, effects)),
        Bool.and(Bool.and(Multi.type_snapshot_valid(actor_types),
          Multi.type_snapshot_valid(target_types)),
          Bool.and(Effects.snapshot_valid(snapshot),
            runtime_witness_roster_valid(witnesses,
              Reducer.state_actors(battle)))))
    case RuntimeSwitch{+source, +incoming}:
      Bool.and(Bool.not(trapped_actor(source, trapped)),
        switch_found_ok(Scheduler.find_actor(source,
            Reducer.state_actors(battle)),
          Scheduler.find_actor(incoming, Reducer.state_actors(battle))))

def runtime_command_ok(command: RuntimeCommand, +state: RuntimeState) -> Bool:
  match state:
    case RuntimeState{battle, rng, encounter, failed, sources, reservations,
        trapped, defenders, effects}:
      runtime_command_in_state(command, battle, trapped, defenders, effects)

def runtime_commands_ok(
  commands: List<&2, RuntimeCommand>, +state: RuntimeState
) -> Bool:
  match commands:
    case Nil{}:
      True{}
    case command <> rest:
      Bool.and(runtime_command_ok(command, state),
        runtime_commands_ok(rest, state))

def first_source(commands: List<&2, RuntimeCommand>) -> Model.ActorId:
  match commands:
    case Nil{}:
      Model.ActorId{0n}
    case command <> rest:
      RuntimeCommand.actor(command)

def runtime_precheck(
  duplicate: Bool, trainer_escape: Bool, semantic_ok: Bool
) -> Bool:
  Bool.and(Bool.not(Bool.or(duplicate, trainer_escape)), semantic_ok)

def semantic_diagnostic(
  commands: List<&2, RuntimeCommand>
) -> List<&2, Model.Diagnostic>:
  match commands:
    case RuntimeSwitch{source, incoming} <> rest:
      [Model.SwitchInvalid{source, incoming}]
    case RuntimeMove{source, target, move, windup, recovery, cooldown, priority,
        recoil, attacker} <> rest:
      [Model.TargetInvalid{source, target}]
    case RuntimeEffectMove{source, target, move, windup, recovery, cooldown,
        priority, recoil, attacker, program, snapshot} <> rest:
      [Model.TargetInvalid{source, target}]
    case RuntimeMixedMove{source, target, windup, recovery, priority, recoil,
        attacker, plan, actor_types, target_types, witnesses, snapshot} <> rest:
      [Model.TargetInvalid{source, target}]
    case command <> rest:
      [Model.ActorNotReady{RuntimeCommand.actor(command)}]
    case Nil{}:
      [Model.IncompleteBarrier{}]

def runtime_diagnostic(
  duplicate: Bool, trainer_escape: Bool, semantic_ok: Bool,
  commands: List<&2, RuntimeCommand>
) -> List<&2, Model.Diagnostic>:
  match duplicate:
    case True{}:
      [Model.SourceReserved{first_source(commands)}]
    case False{}:
      match trainer_escape:
        case True{}:
          [Model.EscapeUnavailable{first_source(commands)}]
        case False{}:
          semantic_diagnostic(commands)

def active_speed_put(active: Bool, +speed: Nat) -> U32:
  match active:
    case True{}:
      U32.from_nat(Nat.min(speed, 9999n))
    case False{}:
      0

def active_speed(actor: Model.Actor, side: Model.Side) -> U32:
  match actor:
    case Model.Actor{id, actor_side, hp, +speed, phase, cooldown}:
      active_speed_put(Participants.active_on_side(
        Model.Actor{id, actor_side, hp, speed, phase, cooldown}, side), speed)

def fastest_speed(
  +side: Model.Side, actors: List<&2, Model.Actor>
) -> U32:
  match actors:
    case Nil{}:
      0
    case actor <> rest:
      U32.max(active_speed(actor, side), fastest_speed(side, rest))

def queue_runtime_state(
  original: RuntimeState, next_battle: Model.BattleState,
  commands: List<&2, RuntimeCommand>,
  sources: List<&2, Sources.MoveSource>
) -> RuntimeState:
  match original:
    case RuntimeState{+battle, +rng, encounter, failed_escapes, old_sources,
        +reservations, trapped, defenders, +effects}:
      match battle:
        case Model.BattleState{now, wait_ticks, +actors, events, +sequence, status}:
          RuntimeState{next_battle, rng, encounter, failed_escapes, sources,
            append_reservations(commands, sequence,
              fastest_speed(Model.Player{}, actors),
              fastest_speed(Model.Enemy{}, actors), reservations, effects), trapped,
            defenders, effects}

type RuntimeBattle is Data:
  RuntimeAdvanced{state: Model.BattleState, emitted: List<&2, Model.TransitionEvent>}
  RuntimeTerminal{state: Model.BattleState, emitted: List<&2, Model.TransitionEvent>}
  RuntimeStalled{state: Model.BattleState, emitted: List<&2, Model.TransitionEvent>}
  RuntimeRejected{state: Model.BattleState, diagnostics: List<&2, Model.Diagnostic>}

type RuntimeSubmitResult is Data:
  RuntimeAccepted{state: RuntimeState, emitted: List<&2, Model.BattleEvent>}
  RuntimeSubmitRejected{state: RuntimeState, diagnostics: List<&2, Model.Diagnostic>}

def drive_result(result: Driver.DriveResult) -> RuntimeBattle:
  match result:
    case Driver.DriveBoundary{state, emitted}:
      RuntimeAdvanced{state, emitted}
    case Driver.DriveTerminal{state, emitted}:
      RuntimeTerminal{state, emitted}
    case Driver.DriveStalled{state, emitted}:
      RuntimeStalled{state, emitted}
    case Driver.DriveYielded{state, emitted}:
      RuntimeAdvanced{state, emitted}

def submit_result(
  +fuel: Nat, result: Model.SubmitResult
) -> RuntimeBattle:
  match result:
    case Model.Rejected{state, diagnostics}:
      RuntimeRejected{state, diagnostics}
    case Model.Accepted{state, emitted}:
      drive_result(Driver.run(state, fuel))

def submit(
  +fuel: Nat, +state: Model.BattleState,
  commands: List<&2, Model.Command>
) -> RuntimeBattle:
  submit_result(fuel, Scheduler.submit(state, commands))

def runtime_submit_model(
  +fuel: Nat, original: RuntimeState,
  commands: List<&2, RuntimeCommand>,
  sources: List<&2, Sources.MoveSource>,
  model_result: Model.SubmitResult
) -> RuntimeSubmitResult:
  match model_result:
    case Model.Rejected{state, diagnostics}:
      RuntimeSubmitRejected{original, diagnostics}
    case Model.Accepted{state, emitted}:
      RuntimeAccepted{queue_runtime_state(original, state, commands, sources), emitted}

def runtime_battle(state: RuntimeState) -> Model.BattleState:
  match state:
    case RuntimeState{battle, rng, encounter, failed_escapes, sources,
        reservations, trapped, defenders, effects}:
      battle

def runtime_sources(state: RuntimeState) -> List<&2, Sources.MoveSource>:
  match state:
    case RuntimeState{battle, rng, encounter, failed_escapes, sources,
        reservations, trapped, defenders, effects}:
      sources

def runtime_now(state: RuntimeState) -> U32:
  match state:
    case RuntimeState{battle, rng, encounter, failed_escapes, sources,
        reservations, trapped, defenders, effects}:
      match battle:
        case Model.BattleState{now, wait_ticks, actors, events, sequence, status}:
          now

def runtime_reserve_result(
  +fuel: Nat, +original: RuntimeState,
  +commands: List<&2, RuntimeCommand>,
  reserved: Sources.ReserveResult
) -> RuntimeSubmitResult:
  match reserved:
    case Sources.SourcesRejected{sources}:
      RuntimeSubmitRejected{original,
        [Model.SourceReserved{first_source(commands)}]}
    case Sources.SourcesReserved{sources}:
      runtime_submit_model(fuel, original, commands, sources,
        Scheduler.submit(runtime_battle(original), runtime_model_commands(commands)))

def runtime_submit_checked(
  ok: Bool, duplicate: Bool, trainer_escape: Bool, semantic_ok: Bool,
  +fuel: Nat, +original: RuntimeState,
  commands: List<&2, RuntimeCommand>
) -> RuntimeSubmitResult:
  match ok:
    case False{}:
      RuntimeSubmitRejected{original, runtime_diagnostic(duplicate,
        trainer_escape, semantic_ok, commands)}
    case True{}:
      +ordered = List.sort(~RuntimeCommand, ~RuntimeCommand.le, commands)
      runtime_reserve_result(fuel, original, ordered,
        Sources.reserve_batch(runtime_now(original),
          runtime_source_requests(ordered), runtime_sources(original)))

def runtime_submit(
  +fuel: Nat, +original: RuntimeState,
  +commands: List<&2, RuntimeCommand>
) -> RuntimeSubmitResult:
  match original:
    case RuntimeState{battle, rng, encounter, failed_escapes, sources,
        reservations, trapped, defenders, effects}:
      +duplicate = duplicate_runtime_source(commands, False{})
      +trainer_escape = Bool.and(has_trainer_escape(commands),
        trainer_kind(encounter))
      +semantic_ok = runtime_commands_ok(commands, original)
      runtime_submit_checked(
        runtime_precheck(duplicate, trainer_escape, semantic_ok), duplicate,
        trainer_escape, semantic_ok, fuel, original, commands)

def queued_sequence(queued: QueuedReservation) -> Nat:
  match queued:
    case QueuedMove{sequence, reservation, attacker}:
      sequence
    case QueuedEffectMove{sequence, reservation, attacker, recoil, program,
        snapshot}:
      sequence
    case QueuedMixedMove{sequence, reservation, second_source, attacker,
        recoil, plan, actor_types, target_types, witnesses, snapshot}:
      sequence
    case QueuedSwitch{sequence, source, incoming}:
      sequence
    case QueuedEscape{sequence, source, player_speed, enemy_speed}:
      sequence

def find_queued_put(
  equal: Bool, queued: QueuedReservation,
  fallback: Maybe<&2, QueuedReservation>
) -> Maybe<&2, QueuedReservation>:
  match equal:
    case True{}:
      Some{queued}
    case False{}:
      fallback

def find_queued(
  +sequence: Nat, reservations: List<&2, QueuedReservation>
) -> Maybe<&2, QueuedReservation>:
  match reservations:
    case Nil{}:
      None{}
    case +queued <> rest:
      find_queued_put(Nat.is_eq(sequence, queued_sequence(queued)), queued,
        find_queued(sequence, rest))

def remove_queued_put(
  equal: Bool, queued: QueuedReservation,
  rest: List<&2, QueuedReservation>,
  filtered: List<&2, QueuedReservation>
) -> List<&2, QueuedReservation>:
  match equal:
    case True{}:
      rest
    case False{}:
      queued <> filtered

def remove_queued(
  +sequence: Nat, reservations: List<&2, QueuedReservation>
) -> List<&2, QueuedReservation>:
  match reservations:
    case Nil{}:
      Nil{}
    case +queued <> +rest:
      remove_queued_put(Nat.is_eq(sequence, queued_sequence(queued)), queued,
        rest, remove_queued(sequence, rest))

def find_defender_put(
  equal: Bool, profile: CombatProfile, fallback: Maybe<&2, CombatProfile>
) -> Maybe<&2, CombatProfile>:
  match equal:
    case True{}:
      Some{profile}
    case False{}:
      fallback

def find_defender(
  +target: Model.ActorId, defenders: List<&2, DefenderSnapshot>
) -> Maybe<&2, CombatProfile>:
  match defenders:
    case Nil{}:
      None{}
    case DefenderSnapshot{+actor, profile} <> rest:
      find_defender_put(Model.ActorId.eq(target, actor), profile,
        find_defender(target, rest))

def combine_profiles(
  attacker: CombatProfile, defender: CombatProfile
) -> CombatProfile:
  match attacker defender:
    case CombatProfile{mode, accuracy, ignored_evasion, power, level, attack,
        ignored_defense, critical_bonus}
        CombatProfile{ignored_mode, ignored_accuracy, evasion, ignored_power,
        ignored_level, ignored_attack, defense, ignored_critical}:
      CombatProfile{mode, accuracy, evasion, power, level, attack, defense,
        critical_bonus}

def sync_effect_actor_hp(
  found: Maybe<&2, Model.Actor>, actor: Effects.EffectActor
) -> Effects.EffectActor:
  match found actor:
    case None{} actor:
      actor
    case Some{Model.Actor{id, side, hp, speed, phase, cooldown}}
        Effects.EffectActor{ignored_hp, max_hp, physical_defense,
        special_defense, stages, statuses, protected, immunities}:
      Effects.EffectActor{U32.from_nat(hp), max_hp, physical_defense,
        special_defense, stages, statuses, protected, immunities}

def sync_effect_world_hps(
  +source_id: Model.ActorId, +target_id: Model.ActorId,
  +world: Effects.EffectWorld, +actors: List<&2, Model.Actor>
) -> Effects.EffectWorld:
  match world:
    case Effects.EffectWorld{+source, +target}:
      +source_value = sync_effect_actor_hp(
        Scheduler.find_actor(source_id, actors), source)
      +target_value = sync_effect_actor_hp(
        Scheduler.find_actor(target_id, actors), target)
      Effects.EffectWorld{source_value, target_value}

def sync_effect_optional(
  effects: Maybe<&2, RuntimeEffectState>, actors: List<&2, Model.Actor>
) -> Maybe<&2, RuntimeEffectState>:
  match effects:
    case None{}:
      None{}
    case Some{RuntimeEffectState{+source, +target, +world}}:
      Some{RuntimeEffectState{source, target,
        sync_effect_world_hps(source, target, world, actors)}}

def runtime_update_scalar(
  original: RuntimeState, battle: Model.BattleState, rng: Rng.RngState,
  +failed_escapes: U32, sources: List<&2, Sources.MoveSource>,
  reservations: List<&2, QueuedReservation>
) -> RuntimeState:
  match original:
    case RuntimeState{old_battle, old_rng, encounter, old_failed, old_sources,
        old_reservations, trapped, defenders, +effects}:
      match battle:
        case Model.BattleState{now, wait_ticks, +actors, events, sequence,
            status}:
          RuntimeState{battle, rng, encounter, failed_escapes, sources,
            reservations, trapped, defenders, sync_effect_optional(effects,
              actors)}

def runtime_update(
  original: RuntimeState, battle: Model.BattleState, rng: Rng.RngState,
  +failed_escapes: U32, sources: List<&2, Sources.MoveSource>,
  reservations: List<&2, QueuedReservation>
) -> RuntimeState:
  match original:
    case RuntimeState{old_battle, old_rng, encounter, old_failed, old_sources,
        old_reservations, trapped, defenders, effects}:
      RuntimeState{battle, rng, encounter, failed_escapes, sources,
        reservations, trapped, defenders, effects}

def runtime_rng(state: RuntimeState) -> Rng.RngState:
  match state:
    case RuntimeState{battle, rng, encounter, failed, sources, reservations,
        trapped, defenders, effects}:
      rng

def runtime_failed(state: RuntimeState) -> U32:
  match state:
    case RuntimeState{battle, rng, encounter, failed, sources, reservations,
        trapped, defenders, effects}:
      failed

def runtime_reservations(
  state: RuntimeState
) -> List<&2, QueuedReservation>:
  match state:
    case RuntimeState{battle, rng, encounter, failed, sources, reservations,
        trapped, defenders, effects}:
      reservations

def runtime_defenders(state: RuntimeState) -> List<&2, DefenderSnapshot>:
  match state:
    case RuntimeState{battle, rng, encounter, failed, sources, reservations,
        trapped, defenders, effects}:
      defenders

type RuntimeAdvanceResult is Data:
  RuntimeStep{
    state: RuntimeState,
    emitted: List<&2, Model.TransitionEvent>,
    combat_events: List<&2, RuntimeEvent>
  }
  RuntimeIdle{state: RuntimeState}
  RuntimeEffectRejected{
    state: RuntimeState,
    diagnostics: List<&2, Effects.EffectDiagnostic>
  }
  RuntimeFault{state: RuntimeState, reason: Maybe<&2, Rng.RngSampleResult>}

def reservation_source(reservation: SourceReservation) -> Model.ActorId:
  match reservation:
    case SourceReservation{source, move, target}:
      source

def reservation_move(reservation: SourceReservation) -> Math.MoveId:
  match reservation:
    case SourceReservation{source, move, target}:
      move

def reducer_commit(
  original: RuntimeState, +rng: Rng.RngState,
  sources: List<&2, Sources.MoveSource>,
  reservations: List<&2, QueuedReservation>, +failed: U32,
  combat_events: List<&2, RuntimeEvent>, result: Model.AdvanceResult
) -> RuntimeAdvanceResult:
  match result:
    case Model.Advanced{battle, emitted}:
      RuntimeStep{runtime_update_scalar(original, battle, rng, failed, sources,
        reservations), emitted, combat_events}
    case Model.AdvanceIdle{battle}:
      RuntimeIdle{runtime_update_scalar(original, battle, rng, failed, sources,
        reservations)}

def cancel_move(
  +original: RuntimeState, +tick: U32, +actor: Model.ActorId,
  target: Model.ActorId, +sequence: Nat, remaining: List<&2, Model.BattleEvent>,
  +reservation: SourceReservation
) -> RuntimeAdvanceResult:
  reducer_commit(original, runtime_rng(original),
    Sources.release(reservation_source(reservation), reservation_move(reservation),
      runtime_sources(original)),
    remove_queued(sequence, runtime_reservations(original)),
    runtime_failed(original), [cancel_event(reservation)],
    Reducer.cancelled_transition(runtime_battle(original), tick, actor, remaining))

def fizzle_move(
  +original: RuntimeState, +tick: U32, +actor: Model.ActorId,
  +target: Model.ActorId, +recovery: U32, +cooldown: U32, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>, +reservation: SourceReservation
) -> RuntimeAdvanceResult:
  reducer_commit(original, runtime_rng(original),
    Sources.charge_source(reservation_source(reservation),
      reservation_move(reservation), U32.add(tick, cooldown),
      runtime_sources(original)),
    remove_queued(sequence, runtime_reservations(original)),
    runtime_failed(original), [fizzle_event(reservation)],
    Reducer.fizzle_action(runtime_battle(original), tick, actor, target,
      recovery, 0, remaining))

def commit_action_event(
  event: RuntimeEvent, +original: RuntimeState, +rng: Rng.RngState,
  +tick: U32, +actor: Model.ActorId, +target: Model.ActorId,
  +recovery: U32, +cooldown: U32, +recoil: Nat, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>, +reservation: SourceReservation
) -> RuntimeAdvanceResult:
  match event:
    case RuntimeMiss{source, event_target, draw}:
      reducer_commit(original, rng,
        Sources.charge_source(reservation_source(reservation),
          reservation_move(reservation), U32.add(tick, cooldown),
          runtime_sources(original)),
        remove_queued(sequence, runtime_reservations(original)),
        runtime_failed(original), [event],
        Reducer.valid_action(runtime_battle(original), tick, actor, target,
          recovery, 0, 0n, 0n, remaining))
    case RuntimeNoDamage{source, event_target, critical}:
      reducer_commit(original, rng,
        Sources.charge_source(reservation_source(reservation),
          reservation_move(reservation), U32.add(tick, cooldown),
          runtime_sources(original)),
        remove_queued(sequence, runtime_reservations(original)),
        runtime_failed(original), [event],
        Reducer.valid_action(runtime_battle(original), tick, actor, target,
          recovery, 0, 0n, 0n, remaining))
    case RuntimeHit{source, event_target, +damage, critical}:
      reducer_commit(original, rng,
        Sources.charge_source(reservation_source(reservation),
          reservation_move(reservation), U32.add(tick, cooldown),
          runtime_sources(original)),
        remove_queued(sequence, runtime_reservations(original)),
        runtime_failed(original), [event],
        Reducer.valid_action(runtime_battle(original), tick, actor, target,
          recovery, 0, U32.to_nat(damage), recoil, remaining))
    case _:
      RuntimeFault{original, None{}}

def resolved_move(
  result: ActionResult, +original: RuntimeState, +tick: U32,
  +actor: Model.ActorId, +target: Model.ActorId, +recovery: U32,
  +cooldown: U32, +recoil: Nat, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>, +reservation: SourceReservation
) -> RuntimeAdvanceResult:
  match result:
    case ActionCommitted{rng, event}:
      commit_action_event(event, original, rng, tick, actor, target, recovery,
        cooldown, recoil, sequence, remaining, reservation)
    case ActionFizzled{rng, event}:
      RuntimeFault{original, None{}}
    case ActionCancelled{rng, event}:
      RuntimeFault{original, None{}}
    case ActionFault{rng, reason}:
      RuntimeFault{original, Some{reason}}

def defender_move(
  found: Maybe<&2, CombatProfile>, attacker: CombatProfile,
  +reservation: SourceReservation, +original: RuntimeState, +tick: U32,
  +actor: Model.ActorId, +target: Model.ActorId, +recovery: U32,
  +cooldown: U32, +recoil: Nat, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  match found:
    case None{}:
      RuntimeFault{original, None{}}
    case Some{defender}:
      resolved_move(resolve_profile(reservation, runtime_rng(original),
          combine_profiles(attacker, defender)), original, tick, actor, target,
        recovery, cooldown, recoil, sequence, remaining, reservation)

def target_move(
  valid: Bool, attacker: CombatProfile, +reservation: SourceReservation,
  +original: RuntimeState, +tick: U32, +actor: Model.ActorId,
  +target: Model.ActorId, +recovery: U32, +cooldown: U32, +recoil: Nat,
  +sequence: Nat, remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  match valid:
    case False{}:
      fizzle_move(original, tick, actor, target, recovery, cooldown, sequence,
        remaining, reservation)
    case True{}:
      defender_move(find_defender(target, runtime_defenders(original)), attacker,
        reservation, original, tick, actor, target, recovery, cooldown, recoil,
        sequence, remaining)

def target_actor_move(
  found: Maybe<&2, Model.Actor>, actor_state: Model.Actor,
  attacker: CombatProfile, +reservation: SourceReservation,
  +original: RuntimeState, +tick: U32, +actor: Model.ActorId,
  +target: Model.ActorId, +recovery: U32, +cooldown: U32, +recoil: Nat,
  +sequence: Nat, remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  match found:
    case None{}:
      fizzle_move(original, tick, actor, target, recovery, cooldown, sequence,
        remaining, reservation)
    case Some{+target_state}:
      target_move(Scheduler.target_ok(actor_state, target_state), attacker,
        reservation, original, tick, actor, target, recovery, cooldown, recoil,
        sequence, remaining)

def actor_ready_move(
  ready: Bool, actor_state: Model.Actor, attacker: CombatProfile,
  +reservation: SourceReservation, +original: RuntimeState, +tick: U32,
  +actor: Model.ActorId, +target: Model.ActorId, +recovery: U32,
  +cooldown: U32, +recoil: Nat, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  match ready:
    case False{}:
      cancel_move(original, tick, actor, target, sequence, remaining,
        reservation)
    case True{}:
      target_actor_move(Scheduler.find_actor(target,
          Reducer.state_actors(runtime_battle(original))), actor_state, attacker,
        reservation, original, tick, actor, target, recovery, cooldown, recoil,
        sequence, remaining)

def actor_move(
  found: Maybe<&2, Model.Actor>, attacker: CombatProfile,
  +reservation: SourceReservation, +original: RuntimeState, +tick: U32,
  +actor: Model.ActorId, +target: Model.ActorId, +recovery: U32,
  +cooldown: U32, +recoil: Nat, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  match found:
    case None{}:
      cancel_move(original, tick, actor, target, sequence, remaining,
        reservation)
    case Some{+actor_state}:
      actor_ready_move(Reducer.actor_can_execute(actor_state), actor_state,
        attacker, reservation, original, tick, actor, target, recovery,
        cooldown, recoil, sequence, remaining)

def execute_queued_move(
  +reservation: SourceReservation, attacker: CombatProfile,
  +original: RuntimeState, +tick: U32, +actor: Model.ActorId,
  +target: Model.ActorId, +recovery: U32, +cooldown: U32, +recoil: Nat,
  +sequence: Nat, remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  actor_move(Scheduler.find_actor(actor,
      Reducer.state_actors(runtime_battle(original))), attacker, reservation,
    original, tick, actor, target, recovery, cooldown, recoil, sequence,
    remaining)

def utility_failure(
  +original: RuntimeState, +tick: U32, +actor: Model.ActorId,
  +target: Model.ActorId, +recovery: U32, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  reducer_commit(original, runtime_rng(original), runtime_sources(original),
    remove_queued(sequence, runtime_reservations(original)),
    runtime_failed(original), Nil{},
    Reducer.valid_action(runtime_battle(original), tick, actor, target,
      recovery, 0, 0n, 0n, remaining))

def switch_transition_battle(
  battle: Model.BattleState, +original: RuntimeState, +tick: U32, +actor: Model.ActorId,
  +incoming: Model.ActorId, +recovery: U32, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  match battle:
    case Model.BattleState{now, wait_ticks, actors, events, +next_sequence,
        status}:
      +ready_tick = U32.add(tick, recovery)
      +switched = Participants.apply_switch(actor, incoming, actors)
      +recovering = Reducer.set_recovery(incoming, ready_tick, 0, switched)
      reducer_commit(original, runtime_rng(original), runtime_sources(original),
        remove_queued(sequence, runtime_reservations(original)),
        runtime_failed(original), Nil{},
        Reducer.finish_action(Reducer.battle_status(recovering), tick,
          wait_ticks, recovering, remaining, next_sequence,
          Model.BattleActorSwitched{actor, incoming},
          Reducer.schedule_ready(tick, incoming, recovery, next_sequence)))

def switch_transition(
  +original: RuntimeState, +tick: U32, +actor: Model.ActorId,
  +incoming: Model.ActorId, +recovery: U32, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  switch_transition_battle(runtime_battle(original), original, tick, actor,
    incoming, recovery, sequence, remaining)

def incoming_switch_ok(
  outgoing: Model.Actor, incoming: Model.Actor
) -> Bool:
  match outgoing incoming:
    case Model.Actor{out_id, out_side, out_hp, out_speed, out_phase, out_cd}
        Model.Actor{in_id, in_side, 0n, in_speed, in_phase, in_cd}:
      False{}
    case Model.Actor{out_id, out_side, out_hp, out_speed, out_phase, out_cd}
        Model.Actor{in_id, in_side, 1n+in_hp, in_speed, Model.Benched{}, in_cd}:
      Participants.same_side(out_side, in_side)
    case _ _:
      False{}

def switch_incoming_ok(
  valid: Bool, +original: RuntimeState, +tick: U32,
  +actor: Model.ActorId, +incoming: Model.ActorId, +recovery: U32,
  +sequence: Nat, remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  match valid:
    case True{}:
      switch_transition(original, tick, actor, incoming, recovery, sequence,
        remaining)
    case False{}:
      utility_failure(original, tick, actor, incoming, recovery, sequence,
        remaining)

def switch_incoming(
  found: Maybe<&2, Model.Actor>, outgoing: Model.Actor,
  +original: RuntimeState, +tick: U32, +actor: Model.ActorId,
  +incoming: Model.ActorId, +recovery: U32, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  match found:
    case None{}:
      utility_failure(original, tick, actor, incoming, recovery, sequence,
        remaining)
    case Some{incoming_actor}:
      switch_incoming_ok(incoming_switch_ok(outgoing, incoming_actor), original,
        tick, actor, incoming, recovery, sequence, remaining)

def switch_actor_ready(
  ready: Bool, outgoing: Model.Actor, +original: RuntimeState, +tick: U32,
  +actor: Model.ActorId, +incoming: Model.ActorId, +recovery: U32,
  +sequence: Nat, remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  match ready:
    case False{}:
      reducer_commit(original, runtime_rng(original), runtime_sources(original),
        remove_queued(sequence, runtime_reservations(original)),
        runtime_failed(original), Nil{},
        Reducer.cancelled_transition(runtime_battle(original), tick, actor,
          remaining))
    case True{}:
      switch_incoming(Scheduler.find_actor(incoming,
          Reducer.state_actors(runtime_battle(original))), outgoing, original,
        tick, actor, incoming, recovery, sequence, remaining)

def switch_actor(
  found: Maybe<&2, Model.Actor>, +original: RuntimeState, +tick: U32,
  +actor: Model.ActorId, +incoming: Model.ActorId, +recovery: U32,
  +sequence: Nat, remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  match found:
    case None{}:
      reducer_commit(original, runtime_rng(original), runtime_sources(original),
        remove_queued(sequence, runtime_reservations(original)),
        runtime_failed(original), Nil{},
        Reducer.cancelled_transition(runtime_battle(original), tick, actor,
          remaining))
    case Some{+outgoing}:
      switch_actor_ready(Reducer.actor_can_execute(outgoing), outgoing, original,
        tick, actor, incoming, recovery, sequence, remaining)

def execute_switch(
  +original: RuntimeState, +tick: U32, +actor: Model.ActorId,
  +incoming: Model.ActorId, +recovery: U32, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  switch_actor(Scheduler.find_actor(actor,
      Reducer.state_actors(runtime_battle(original))), original, tick, actor,
    incoming, recovery, sequence, remaining)

def escape_success_battle(
  battle_state: Model.BattleState, +original: RuntimeState,
  +rng: Rng.RngState, +tick: U32,
  +actor: Model.ActorId, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  match battle_state:
    case Model.BattleState{now, wait_ticks, actors, events, next_sequence,
        status}:
      +battle = {Model.BattleState{tick, wait_ticks, actors, Nil{},
        next_sequence, Model.Escaped{}} : Model.BattleState}
      RuntimeStep{runtime_update(original, battle, rng,
        runtime_failed(original), runtime_sources(original),
        remove_queued(sequence, runtime_reservations(original))),
        [Model.BattleEscapeSucceeded{actor},
         Model.BattleCompleted{Model.Escaped{}, tick},
         Model.BattlePendingDiscarded{
           List.length(&2, Model.BattleEvent, remaining)}], Nil{}}

def escape_success(
  +original: RuntimeState, +rng: Rng.RngState, +tick: U32,
  +actor: Model.ActorId, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  escape_success_battle(runtime_battle(original), original, rng, tick, actor,
    sequence, remaining)

def escape_failure_battle(
  battle_state: Model.BattleState, +original: RuntimeState,
  +rng: Rng.RngState, +failed: U32, +tick: U32,
  +actor: Model.ActorId, +recovery: U32, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  match battle_state:
    case Model.BattleState{now, wait_ticks, actors, events, +next_sequence,
        status}:
      +ready_tick = U32.add(tick, recovery)
      +recovering = Reducer.set_recovery(actor, ready_tick, 0, actors)
      reducer_commit(original, rng, runtime_sources(original),
        remove_queued(sequence, runtime_reservations(original)), failed, Nil{},
        Reducer.finish_action(Reducer.battle_status(recovering), tick,
          wait_ticks, recovering, remaining, next_sequence,
          Model.BattleEscapeFailed{actor},
          Reducer.schedule_ready(tick, actor, recovery, next_sequence)))

def escape_failure(
  +original: RuntimeState, +rng: Rng.RngState, +failed: U32, +tick: U32,
  +actor: Model.ActorId, +recovery: U32, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  escape_failure_battle(runtime_battle(original), original, rng, failed, tick,
    actor, recovery, sequence, remaining)

def escape_result_commit(
  result: EscapeResult, +original: RuntimeState, +tick: U32,
  +actor: Model.ActorId, +recovery: U32, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  match result:
    case EscapeSucceeded{rng}:
      escape_success(original, rng, tick, actor, sequence, remaining)
    case EscapeFailed{rng, failed}:
      escape_failure(original, rng, failed, tick, actor, recovery, sequence,
        remaining)
    case _:
      RuntimeFault{original, None{}}

def execute_escape_ready(
  ready: Bool, +original: RuntimeState, +tick: U32, +actor: Model.ActorId,
  +recovery: U32, +sequence: Nat, +player_speed: U32, +enemy_speed: U32,
  remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  match ready:
    case False{}:
      reducer_commit(original, runtime_rng(original), runtime_sources(original),
        remove_queued(sequence, runtime_reservations(original)),
        runtime_failed(original), Nil{},
        Reducer.cancelled_transition(runtime_battle(original), tick, actor,
          remaining))
    case True{}:
      match original:
        case RuntimeState{battle, rng, encounter, failed, sources, reservations,
            trapped, defenders, effects}:
          escape_result_commit(escape_attempt(encounter, rng, failed,
            player_speed, enemy_speed), original, tick, actor, recovery,
            sequence, remaining)

def execute_escape_actor(
  found: Maybe<&2, Model.Actor>, +original: RuntimeState, +tick: U32,
  +actor: Model.ActorId, +recovery: U32, +sequence: Nat,
  +player_speed: U32, +enemy_speed: U32,
  remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  match found:
    case None{}:
      reducer_commit(original, runtime_rng(original), runtime_sources(original),
        remove_queued(sequence, runtime_reservations(original)),
        runtime_failed(original), Nil{},
        Reducer.cancelled_transition(runtime_battle(original), tick, actor,
          remaining))
    case Some{+actor_state}:
      execute_escape_ready(Reducer.actor_can_execute(actor_state), original,
        tick, actor, recovery, sequence, player_speed, enemy_speed, remaining)

def execute_escape(
  +original: RuntimeState, +tick: U32, +actor: Model.ActorId,
  +recovery: U32, +sequence: Nat, +player_speed: U32, +enemy_speed: U32,
  remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  execute_escape_actor(Scheduler.find_actor(actor,
      Reducer.state_actors(runtime_battle(original))), original, tick, actor,
    recovery, sequence, player_speed, enemy_speed, remaining)

def reducer_step_runtime(+original: RuntimeState) -> RuntimeAdvanceResult:
  reducer_commit(original, runtime_rng(original), runtime_sources(original),
    runtime_reservations(original), runtime_failed(original), Nil{},
    Reducer.step(runtime_battle(original)))

def effect_phase_nonzero(phase: Model.Phase) -> Model.Phase:
  match phase:
    case Model.Defeated{}: Model.Ready{}
    case other: other

def effect_phase_for_zero(zero: Bool, phase: Model.Phase) -> Model.Phase:
  match zero:
    case True{}: Model.Defeated{}
    case False{}: effect_phase_nonzero(phase)

def effect_phase_for_hp(+hp: U32, phase: Model.Phase) -> Model.Phase:
  effect_phase_for_zero(U32.is_zero(hp), phase)

def effect_hp_for_actors(
  source_equal: Bool, target_equal: Bool,
  source_actor: Effects.EffectActor, target_actor: Effects.EffectActor,
  fallback: U32
) -> U32:
  match source_equal target_equal:
    case True{} _: Effects.actor_hp(source_actor)
    case False{} True{}: Effects.actor_hp(target_actor)
    case False{} False{}: fallback

def effect_hp_for_match(
  source_equal: Bool, target_equal: Bool, world: Effects.EffectWorld,
  fallback: U32
) -> U32:
  match world:
    case Effects.EffectWorld{source_actor, target_actor}:
      effect_hp_for_actors(source_equal, target_equal, source_actor,
        target_actor, fallback)

def effect_hp_for_actor(
  +wanted: Model.ActorId, source: Model.ActorId, target: Model.ActorId,
  world: Effects.EffectWorld, fallback: U32
) -> U32:
  effect_hp_for_match(Model.ActorId.eq(wanted, source),
    Model.ActorId.eq(wanted, target), world, fallback)

def sync_effect_actor(
  +wanted: Model.ActorId, +source: Model.ActorId, +target: Model.ActorId,
  +world: Effects.EffectWorld, actors: List<&2, Model.Actor>
) -> List<&2, Model.Actor>:
  match actors:
    case Nil{}:
      Nil{}
    case +actor <> rest:
      match actor:
        case Model.Actor{+id, +side, +hp, +speed, +phase, +cooldown}:
          +fallback = U32.from_nat(hp)
          +next_hp = effect_hp_for_actor(wanted, source, target, world, fallback)
          Model.Actor{id, side, U32.to_nat(next_hp), speed,
            effect_phase_for_hp(next_hp, phase), cooldown} <>
            sync_effect_actor(wanted, source, target, world, rest)

def sync_effect_actors(
  +source: Model.ActorId, +target: Model.ActorId, +world: Effects.EffectWorld,
  actors: List<&2, Model.Actor>
) -> List<&2, Model.Actor>:
  sync_effect_actor(target, source, target, world,
    sync_effect_actor(source, source, target, world, actors))

def effect_damage_total(records: List<&2, Effects.DamageRecord>) -> Nat:
  match records:
    case Nil{}:
      0n
    case Effects.DamageRecord{node, actual} <> rest:
      Nat.add(U32.to_nat(actual), effect_damage_total(rest))

def runtime_update_effect(
  original: RuntimeState, battle: Model.BattleState, rng: Rng.RngState,
  +failed_escapes: U32, sources: List<&2, Sources.MoveSource>,
  reservations: List<&2, QueuedReservation>, world: Effects.EffectWorld
) -> RuntimeState:
  match original:
    case RuntimeState{old_battle, old_rng, encounter, old_failed, old_sources,
        old_reservations, trapped, defenders, effects}:
      match effects:
        case None{}:
          RuntimeState{battle, rng, encounter, failed_escapes, sources,
            reservations, trapped, defenders, None{}}
        case Some{RuntimeEffectState{source, target, old_world}}:
          RuntimeState{battle, rng, encounter, failed_escapes, sources,
            reservations, trapped, defenders,
            Some{RuntimeEffectState{source, target, world}}}

def effect_commit_transition(
  result: Model.AdvanceResult, +original: RuntimeState, +rng: Rng.RngState,
  events: List<&2, Effects.EffectEvent>, +tick: U32, +cooldown: U32,
  +sequence: Nat, world: Effects.EffectWorld,
  +reservation: SourceReservation
) -> RuntimeAdvanceResult:
  match result:
    case Model.Advanced{battle, emitted}:
      RuntimeStep{runtime_update_effect(original, battle, rng,
        runtime_failed(original),
        Sources.charge_source(reservation_source(reservation),
          reservation_move(reservation), U32.add(tick, cooldown),
          runtime_sources(original)),
        remove_queued(sequence, runtime_reservations(original)), world),
        emitted, [RuntimeEffectsCommitted{events}]}
    case Model.AdvanceIdle{battle}:
      RuntimeIdle{runtime_update_effect(original, battle, rng,
        runtime_failed(original), runtime_sources(original),
        remove_queued(sequence, runtime_reservations(original)), world)}

def effect_commit_world(
  +world: Effects.EffectWorld, rng: Rng.RngState,
  events: List<&2, Effects.EffectEvent>,
  records: List<&2, Effects.DamageRecord>, +original: RuntimeState,
  +tick: U32, +actor: Model.ActorId, +target: Model.ActorId,
  +recovery: U32, +cooldown: U32, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>, +reservation: SourceReservation
) -> RuntimeAdvanceResult:
  match original:
    case RuntimeState{+battle_state, old_rng, encounter, failed, sources,
        reservations, trapped, defenders, effects}:
      match battle_state:
        case Model.BattleState{now, wait_ticks, +actors, +pending,
            +next_sequence, status}:
          +synced = sync_effect_actors(actor, target, world, actors)
          +ready_tick = U32.add(tick, recovery)
          +recovered = Reducer.set_recovery(actor, ready_tick,
            U32.add(tick, 0), synced)
          effect_commit_transition(Reducer.finish_action(
            Reducer.battle_status(recovered), tick, wait_ticks, recovered,
            remaining, next_sequence,
            Model.BattleActionExecuted{actor, target,
              effect_damage_total(records), 0n},
            Reducer.schedule_ready(tick, actor, recovery, next_sequence)),
            original, rng, events, tick, cooldown, sequence, world, reservation)

def effect_commit_result(
  result: Effects.EffectResult, +original: RuntimeState, +tick: U32,
  +actor: Model.ActorId, +target: Model.ActorId, +recovery: U32,
  +cooldown: U32, +sequence: Nat, remaining: List<&2, Model.BattleEvent>,
  +reservation: SourceReservation
) -> RuntimeAdvanceResult:
  match result:
    case Effects.EffectsCommitted{world, rng, events, damage}:
      effect_commit_world(world, rng, events, damage, original, tick, actor,
        target, recovery, cooldown, sequence, remaining, reservation)
    case Effects.EffectsRejected{world, rng, diagnostics}:
      RuntimeEffectRejected{original, diagnostics}
    case Effects.EffectsFaulted{world, rng, reason}:
      RuntimeFault{original, Some{reason}}

def execute_effect_queued(
  +reservation: SourceReservation, program: Effects.EffectProgram,
  snapshot: Effects.ActionSnapshot, +original: RuntimeState, +tick: U32,
  +actor: Model.ActorId, +target: Model.ActorId, +recovery: U32,
  +cooldown: U32, +sequence: Nat, remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  match original:
    case RuntimeState{battle, rng, encounter, failed, sources, reservations,
        trapped, defenders, effects}:
      match effects:
        case None{}:
          RuntimeFault{original, None{}}
        case Some{RuntimeEffectState{source, effect_target, world}}:
          effect_commit_result(Effects.attempt(program, world, snapshot, rng,
            True{}), original,
            tick, actor, target, recovery, cooldown, sequence, remaining,
            reservation)

def runtime_effect_target_types(target: Effects.EffectTarget,
  actor_types: List<&2, Multi.TypeId>,
  target_types: List<&2, Multi.TypeId>) -> List<&2, Multi.TypeId>:
  match target:
    case Effects.Source{}: actor_types
    case Effects.Target{}: target_types

def runtime_mixed_typed_damage(+category: Effects.DamageCategory,
  +target: Effects.EffectTarget, +power: U32,
  components: List<&2, Multi.TypeId>, +actor_types: List<&2, Multi.TypeId>,
  target_types: List<&2, Multi.TypeId>, +world: Effects.EffectWorld,
  +snapshot: Effects.ActionSnapshot) -> Multi.MultiDamageResult:
  match snapshot:
    case Effects.ActionSnapshot{+level, physical_attack, special_attack,
        accuracy, accuracy_mode, physical_damage, critical_bonus}:
      Multi.resolve_multi_type(
        Multi.DamageProfile{level, Effects.category_attack(category, snapshot),
          Effects.category_defense(category,
            Effects.target_actor(target, world))},
        power, components, actor_types,
        runtime_effect_target_types(target, actor_types, target_types))

def runtime_mixed_result_program(effects: List<&2, Effects.Effect>,
  components: List<&2, Multi.TypeId>, actor_types: List<&2, Multi.TypeId>,
  target_types: List<&2, Multi.TypeId>, +world: Effects.EffectWorld,
  +snapshot: Effects.ActionSnapshot) -> Multi.MultiDamageResult:
  match effects:
    case Effects.Leaf{Effects.Damage{node, effect_target, category, power}} <> rest:
      runtime_mixed_typed_damage(category, effect_target, power, components,
        actor_types, target_types, world, snapshot)
    case effect <> rest:
      runtime_mixed_result_program(rest, components, actor_types, target_types,
        world, snapshot)
    case Nil{}:
      Multi.MultiDamageResolved{Nil{}, 0}

def runtime_mixed_result(program: Effects.EffectProgram,
  components: List<&2, Multi.TypeId>, actor_types: List<&2, Multi.TypeId>,
  target_types: List<&2, Multi.TypeId>, +world: Effects.EffectWorld,
  +snapshot: Effects.ActionSnapshot) -> Multi.MultiDamageResult:
  match program:
    case Effects.EffectProgram{effects}:
      runtime_mixed_result_program(effects, components, actor_types,
        target_types, world, snapshot)

def runtime_mixed_status_changed(original: RuntimeState,
  events: List<&2, Effects.EffectEvent>) -> Bool:
  match original:
    case RuntimeState{battle, rng, encounter, failed, sources, reservations,
        trapped, defenders,
        Some{RuntimeEffectState{source, target, before}}}:
      Effects.status_event_changes(before, events)
    case _: False{}

def mixed_charge_commit(result: Sources.MixedChargeResult,
  transition: Model.AdvanceResult, +original: RuntimeState, +rng: Rng.RngState,
  reservations: List<&2, QueuedReservation>, +world: Effects.EffectWorld,
  +events: List<&2, Effects.EffectEvent>, +failed: U32, +sequence: Nat,
  recipe_id: Nat, individual: Nat,
  witnesses: List<&2, RuntimeMixWitness>) -> RuntimeAdvanceResult:
  match result transition:
    case Sources.MixedSourcesRejected{sources} _:
      RuntimeFault{original, None{}}
    case Sources.MixedSourcesCharged{sources}
         Model.Advanced{battle, emitted}:
      RuntimeStep{runtime_update_effect(original, battle, rng, failed,
        sources, reservations, world), emitted,
        [RuntimeMixEffectsCommitted{sequence, recipe_id, individual,
          witnesses, events, runtime_mixed_status_changed(original, events)}]}
    case Sources.MixedSourcesCharged{sources} Model.AdvanceIdle{battle}:
      RuntimeIdle{runtime_update_effect(original, battle, rng, failed,
        runtime_sources(original), reservations, world)}

def effect_commit_mixed_battle(battle_state: Model.BattleState,
  +world: Effects.EffectWorld, +rng: Rng.RngState,
  events: List<&2, Effects.EffectEvent>,
  records: List<&2, Effects.DamageRecord>, +original: RuntimeState,
  +tick: U32, +actor: Model.ActorId, +target: Model.ActorId,
  +recovery: U32, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>, +first: Math.MoveId,
  +second: Math.MoveId, +first_cooldown: U32, +second_cooldown: U32,
  recipe_id: Nat, individual: Nat,
  witnesses: List<&2, RuntimeMixWitness>
) -> RuntimeAdvanceResult:
  match battle_state:
    case Model.BattleState{now, wait_ticks, +actors, +pending,
        +next_sequence, status}:
      +synced = sync_effect_actors(actor, target, world, actors)
      +ready_tick = U32.add(tick, recovery)
      +recovered = Reducer.set_recovery(actor, ready_tick, tick, synced)
      +transition = Reducer.finish_action(Reducer.battle_status(recovered),
        tick, wait_ticks, recovered, remaining, next_sequence,
        Model.BattleActionExecuted{actor, target, effect_damage_total(records),
          0n}, Reducer.schedule_ready(tick, actor, recovery, next_sequence))
      mixed_charge_commit(Sources.charge_mixed_pair(tick, actor, first, second,
        first_cooldown, second_cooldown, runtime_sources(original)), transition,
        original, rng, remove_queued(sequence, runtime_reservations(original)),
        world, events, runtime_failed(original), sequence, recipe_id,
        individual, witnesses)

def effect_commit_mixed_world(
  +world: Effects.EffectWorld, +rng: Rng.RngState,
  events: List<&2, Effects.EffectEvent>,
  records: List<&2, Effects.DamageRecord>, +original: RuntimeState,
  +tick: U32, +actor: Model.ActorId, +target: Model.ActorId,
  +recovery: U32, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>, +first: Math.MoveId,
  +second: Math.MoveId, +first_cooldown: U32, +second_cooldown: U32,
  recipe_id: Nat, individual: Nat,
  witnesses: List<&2, RuntimeMixWitness>
) -> RuntimeAdvanceResult:
  effect_commit_mixed_battle(runtime_battle(original), world, rng, events,
    records, original, tick, actor, target, recovery, sequence, remaining,
    first, second, first_cooldown, second_cooldown, recipe_id, individual,
    witnesses)

def effect_commit_mixed_result(result: Effects.EffectResult,
  +original: RuntimeState, +tick: U32, +actor: Model.ActorId,
  +target: Model.ActorId, +recovery: U32, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>, +plan: RuntimeMixPlan,
  witnesses: List<&2, RuntimeMixWitness>) -> RuntimeAdvanceResult:
  match result:
    case Effects.EffectsCommitted{world, rng, events, damage}:
      match plan:
        case RuntimeMixPlan{individual, recipe_id, result_id, +first, +second,
            +first_cooldown, +second_cooldown, program, components}:
          effect_commit_mixed_world(world, rng, events, damage, original, tick,
            actor, target, recovery, sequence, remaining, first, second,
            first_cooldown, second_cooldown, recipe_id, individual, witnesses)
    case Effects.EffectsRejected{world, rng, diagnostics}:
      RuntimeEffectRejected{original, diagnostics}
    case Effects.EffectsFaulted{world, rng, reason}:
      RuntimeFault{original, Some{reason}}

def cancel_mixed_move(+original: RuntimeState, +tick: U32,
  +actor: Model.ActorId, +target: Model.ActorId, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>, +reservation: SourceReservation,
  +second: Math.MoveId) -> RuntimeAdvanceResult:
  reducer_commit(original, runtime_rng(original),
    Sources.release(actor, second, Sources.release(actor,
      reservation_move(reservation), runtime_sources(original))),
    remove_queued(sequence, runtime_reservations(original)),
    runtime_failed(original), [cancel_event(reservation)],
    Reducer.cancelled_transition(runtime_battle(original), tick, actor, remaining))

def fizzle_mixed_commit(result: Sources.MixedChargeResult,
  +original: RuntimeState, +tick: U32, +actor: Model.ActorId,
  +target: Model.ActorId, +recovery: U32, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>) -> RuntimeAdvanceResult:
  match result:
    case Sources.MixedSourcesRejected{sources}:
      RuntimeFault{original, None{}}
    case Sources.MixedSourcesCharged{sources}:
      reducer_commit(original, runtime_rng(original), sources,
        remove_queued(sequence, runtime_reservations(original)),
        runtime_failed(original), [RuntimeFizzle{actor, target}],
        Reducer.fizzle_action(runtime_battle(original), tick, actor, target,
          recovery, 0, remaining))

def fizzle_mixed_move(+original: RuntimeState, +tick: U32,
  +actor: Model.ActorId, +target: Model.ActorId, +recovery: U32,
  +sequence: Nat, remaining: List<&2, Model.BattleEvent>,
  +first: Math.MoveId, +second: Math.MoveId, +first_cooldown: U32,
  +second_cooldown: U32) -> RuntimeAdvanceResult:
  fizzle_mixed_commit(Sources.charge_mixed_pair(tick, actor, first, second,
    first_cooldown, second_cooldown, runtime_sources(original)), original, tick,
    actor, target, recovery, sequence, remaining)

def mixed_target_valid(valid: Bool, +original: RuntimeState, +tick: U32,
  +actor: Model.ActorId, +target: Model.ActorId, +recovery: U32,
  +sequence: Nat, remaining: List<&2, Model.BattleEvent>,
  +plan: RuntimeMixPlan, witnesses: List<&2, RuntimeMixWitness>,
  actor_types: List<&2, Multi.TypeId>, target_types: List<&2, Multi.TypeId>,
  +snapshot: Effects.ActionSnapshot, +world: Effects.EffectWorld) -> RuntimeAdvanceResult:
  match valid:
    case False{}:
      match plan:
        case RuntimeMixPlan{individual, recipe_id, result_id, first, second,
            first_cooldown, second_cooldown, program, components}:
          fizzle_mixed_move(original, tick, actor, target, recovery, sequence,
            remaining, first, second, first_cooldown, second_cooldown)
    case True{}:
      match plan:
        case RuntimeMixPlan{individual, recipe_id, result_id, first, second,
            first_cooldown, second_cooldown, program, components}:
          effect_commit_mixed_result(Effects.attempt_typed(program, world,
            snapshot, runtime_rng(original), True{},
            runtime_mixed_result(program, components, actor_types, target_types,
              world, snapshot)), original, tick, actor, target, recovery,
            sequence, remaining, plan, witnesses)

def mixed_target_found(found: Maybe<&2, Model.Actor>, actor_state: Model.Actor,
  +original: RuntimeState, +tick: U32, +actor: Model.ActorId,
  +target: Model.ActorId, +recovery: U32, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>, +plan: RuntimeMixPlan,
  witnesses: List<&2, RuntimeMixWitness>,
  actor_types: List<&2, Multi.TypeId>, target_types: List<&2, Multi.TypeId>,
  snapshot: Effects.ActionSnapshot, world: Effects.EffectWorld) -> RuntimeAdvanceResult:
  match found:
    case None{}:
      mixed_target_valid(False{}, original, tick, actor, target, recovery,
        sequence, remaining, plan, witnesses, actor_types, target_types,
        snapshot, world)
    case Some{+target_state}:
      mixed_target_valid(Scheduler.target_ok(actor_state, target_state),
        original, tick, actor, target, recovery, sequence, remaining, plan,
        witnesses, actor_types, target_types, snapshot, world)

def mixed_actor_ready(ready: Bool, actor_state: Model.Actor,
  +original: RuntimeState, +tick: U32, +actor: Model.ActorId,
  +target: Model.ActorId, +recovery: U32, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>, +reservation: SourceReservation,
  +second: Math.MoveId, +plan: RuntimeMixPlan,
  witnesses: List<&2, RuntimeMixWitness>,
  actor_types: List<&2, Multi.TypeId>, target_types: List<&2, Multi.TypeId>,
  snapshot: Effects.ActionSnapshot, world: Effects.EffectWorld) -> RuntimeAdvanceResult:
  match ready:
    case False{}:
      cancel_mixed_move(original, tick, actor, target, sequence, remaining,
        reservation, second)
    case True{}:
      mixed_target_found(Scheduler.find_actor(target,
        Reducer.state_actors(runtime_battle(original))), actor_state, original,
        tick, actor, target, recovery, sequence, remaining, plan, witnesses,
        actor_types, target_types, snapshot, world)

def mixed_actor_found(found: Maybe<&2, Model.Actor>,
  +original: RuntimeState, +tick: U32, +actor: Model.ActorId,
  +target: Model.ActorId, +recovery: U32, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>, +reservation: SourceReservation,
  +second: Math.MoveId, +plan: RuntimeMixPlan,
  witnesses: List<&2, RuntimeMixWitness>,
  actor_types: List<&2, Multi.TypeId>, target_types: List<&2, Multi.TypeId>,
  snapshot: Effects.ActionSnapshot, world: Effects.EffectWorld) -> RuntimeAdvanceResult:
  match found:
    case None{}:
      cancel_mixed_move(original, tick, actor, target, sequence, remaining,
        reservation, second)
    case Some{+actor_state}:
      mixed_actor_ready(Reducer.actor_can_execute(actor_state), actor_state,
        original, tick, actor, target, recovery, sequence, remaining,
        reservation, second, plan, witnesses, actor_types, target_types,
        snapshot, world)

def execute_mixed_queued(reservation: SourceReservation,
  +second: Math.MoveId, +plan: RuntimeMixPlan,
  witnesses: List<&2, RuntimeMixWitness>,
  actor_types: List<&2, Multi.TypeId>, target_types: List<&2, Multi.TypeId>,
  snapshot: Effects.ActionSnapshot, +original: RuntimeState, +tick: U32,
  +actor: Model.ActorId, +target: Model.ActorId, +recovery: U32,
  +sequence: Nat, remaining: List<&2, Model.BattleEvent>) -> RuntimeAdvanceResult:
  match original:
    case RuntimeState{battle, rng, encounter, failed, sources, reservations,
        trapped, defenders, effects}:
      match effects:
        case None{}: RuntimeFault{original, None{}}
        case Some{RuntimeEffectState{source, effect_target, world}}:
          +live_witnesses = {runtime_mix_witnesses_live(witnesses,
            List.sort(~Model.Actor, ~runtime_actor_le,
              Reducer.state_actors(battle))) :
            List<&2, RuntimeMixWitness>}
          mixed_actor_found(Scheduler.find_actor(actor,
            Reducer.state_actors(battle)), original, tick, actor, target,
            recovery, sequence, remaining, reservation, second, plan,
            live_witnesses, actor_types, target_types, snapshot, world)


def execute_move_queued(
  queued: QueuedReservation, +original: RuntimeState, +tick: U32,
  +actor: Model.ActorId, +target: Model.ActorId, +recovery: U32,
  +cooldown: U32, +recoil: Nat, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  match queued:
    case QueuedMove{queued_seq, reservation, attacker}:
      execute_queued_move(reservation, attacker, original, tick, actor, target,
        recovery, cooldown, recoil, sequence, remaining)
    case QueuedEffectMove{queued_seq, reservation, attacker, queued_recoil,
        program, snapshot}:
      execute_effect_queued(reservation, program, snapshot, original, tick,
        actor, target, recovery, cooldown, sequence, remaining)
    case QueuedMixedMove{queued_seq, reservation, second_source, attacker,
        queued_recoil, plan, actor_types, target_types, witnesses, snapshot}:
      execute_mixed_queued(reservation, second_source, plan, witnesses,
        actor_types, target_types, snapshot, original, tick, actor, target,
        recovery, sequence, remaining)
    case _:
      RuntimeFault{original, None{}}

def execute_move_found(
  found: Maybe<&2, QueuedReservation>, +original: RuntimeState, +tick: U32,
  +actor: Model.ActorId, +target: Model.ActorId, +recovery: U32,
  +cooldown: U32, +recoil: Nat, +sequence: Nat,
  remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  match found:
    case None{}:
      reducer_step_runtime(original)
    case Some{queued}:
      execute_move_queued(queued, original, tick, actor, target, recovery,
        cooldown, recoil, sequence, remaining)

def execute_switch_queued(
  queued: QueuedReservation, +original: RuntimeState, +tick: U32,
  +actor: Model.ActorId, +target: Model.ActorId, +recovery: U32,
  +sequence: Nat, remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  match queued:
    case QueuedSwitch{queued_seq, source, incoming}:
      execute_switch(original, tick, actor, incoming, recovery, sequence,
        remaining)
    case QueuedEscape{queued_seq, source, player_speed, enemy_speed}:
      execute_escape(original, tick, actor, recovery, sequence, player_speed,
        enemy_speed, remaining)
    case _:
      RuntimeFault{original, None{}}

def execute_utility_found(
  found: Maybe<&2, QueuedReservation>, +original: RuntimeState, +tick: U32,
  +actor: Model.ActorId, +target: Model.ActorId, +recovery: U32,
  +sequence: Nat, remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  match found:
    case None{}:
      RuntimeFault{original, None{}}
    case Some{queued}:
      execute_switch_queued(queued, original, tick, actor, target, recovery,
        sequence, remaining)

def runtime_step_event(
  event: Model.BattleEvent, +original: RuntimeState,
  remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  match event:
    case Model.ReadyEvent{key, actor}:
      reducer_step_runtime(original)
    case Model.ExecuteEvent{Model.EventKey{+tick, phase, priority, speed,
        key_actor, +sequence, ordinal}, actor, target, +recovery, +cooldown,
        damage, +recoil}:
      execute_move_found(find_queued(sequence,
          runtime_reservations(original)), original, tick, actor, target,
        recovery, cooldown, recoil, sequence, remaining)
    case Model.UtilityEvent{Model.EventKey{+tick, phase, priority, speed,
        key_actor, +sequence, ordinal}, actor, target, +recovery}:
      execute_utility_found(find_queued(sequence,
          runtime_reservations(original)), original, tick, actor, target,
        recovery, sequence, remaining)

def driver_runtime(
  result: Driver.DriveResult, +original: RuntimeState
) -> RuntimeAdvanceResult:
  match result:
    case Driver.DriveBoundary{battle, emitted}:
      RuntimeStep{runtime_update(original, battle, runtime_rng(original),
        runtime_failed(original), runtime_sources(original),
        runtime_reservations(original)), emitted, Nil{}}
    case Driver.DriveTerminal{battle, emitted}:
      RuntimeStep{runtime_update(original, battle, runtime_rng(original),
        runtime_failed(original), runtime_sources(original),
        runtime_reservations(original)), emitted, Nil{}}
    case Driver.DriveStalled{battle, emitted}:
      RuntimeStep{runtime_update(original, battle, runtime_rng(original),
        runtime_failed(original), runtime_sources(original),
        runtime_reservations(original)), emitted, Nil{}}
    case Driver.DriveYielded{battle, emitted}:
      RuntimeIdle{runtime_update(original, battle, runtime_rng(original),
        runtime_failed(original), runtime_sources(original),
        runtime_reservations(original))}

def runtime_boundary_state(+original: RuntimeState) -> RuntimeAdvanceResult:
  +battle = Driver.with_status(runtime_battle(original),
    Model.AwaitingCommands{})
  RuntimeStep{runtime_update(original, battle, runtime_rng(original),
    runtime_failed(original), runtime_sources(original),
    runtime_reservations(original)), Nil{}, Nil{}}

def runtime_future_ready(
  ready: List<&2, Model.ActorId>, event: Model.BattleEvent,
  +original: RuntimeState, remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  match ready:
    case Nil{}:
      runtime_step_event(event, original, remaining)
    case actor <> rest:
      runtime_boundary_state(original)

def runtime_due_future(
  future: Bool, event: Model.BattleEvent, +original: RuntimeState,
  remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  match future:
    case False{}:
      runtime_step_event(event, original, remaining)
    case True{}:
      runtime_future_ready(Scheduler.collect_ready_ids(
          Reducer.state_actors(runtime_battle(original))), event, original,
        remaining)

def runtime_due_valid(
  valid: Bool, +due: U32, event: Model.BattleEvent,
  +original: RuntimeState, remaining: List<&2, Model.BattleEvent>
) -> RuntimeAdvanceResult:
  match valid:
    case False{}:
      driver_runtime(Driver.run(runtime_battle(original), 1n), original)
    case True{}:
      runtime_due_future(U32.is_gt(due, runtime_now(original)), event,
        original, remaining)

def runtime_step_events(
  events: List<&2, Model.BattleEvent>, +original: RuntimeState
) -> RuntimeAdvanceResult:
  match events:
    case Nil{}:
      driver_runtime(Driver.run(runtime_battle(original), 1n), original)
    case +event <> rest:
      +due = Reducer.event_due(event)
      runtime_due_valid(U32.is_le(due, 216000), due, event, original, rest)

def runtime_step(+original: RuntimeState) -> RuntimeAdvanceResult:
  match original:
    case RuntimeState{+battle, rng, encounter, failed, sources, reservations,
        trapped, defenders, effects}:
      match battle:
        case Model.BattleState{now, wait_ticks, actors, +events, sequence,
            status}:
          runtime_step_events(events, original)

type RuntimeRunResult is Data:
  RuntimeRunBoundary{
    state: RuntimeState,
    emitted: List<&2, Model.TransitionEvent>,
    combat_events: List<&2, RuntimeEvent>
  }
  RuntimeRunTerminal{
    state: RuntimeState,
    emitted: List<&2, Model.TransitionEvent>,
    combat_events: List<&2, RuntimeEvent>
  }
  RuntimeRunStalled{
    state: RuntimeState,
    emitted: List<&2, Model.TransitionEvent>,
    combat_events: List<&2, RuntimeEvent>
  }
  RuntimeRunYielded{
    state: RuntimeState,
    emitted: List<&2, Model.TransitionEvent>,
    combat_events: List<&2, RuntimeEvent>
  }
  RuntimeRunRejected{
    state: RuntimeState,
    diagnostics: List<&2, Effects.EffectDiagnostic>
  }
  RuntimeRunFault{
    state: RuntimeState,
    reason: Maybe<&2, Rng.RngSampleResult>
  }

type RuntimeCursor is Data:
  RuntimeCursorActive{
    state: RuntimeState,
    emitted: List<&2, Model.TransitionEvent>,
    combat_events: List<&2, RuntimeEvent>
  }
  RuntimeCursorBoundary{
    state: RuntimeState,
    emitted: List<&2, Model.TransitionEvent>,
    combat_events: List<&2, RuntimeEvent>
  }
  RuntimeCursorTerminal{
    state: RuntimeState,
    emitted: List<&2, Model.TransitionEvent>,
    combat_events: List<&2, RuntimeEvent>
  }
  RuntimeCursorStalled{
    state: RuntimeState,
    emitted: List<&2, Model.TransitionEvent>,
    combat_events: List<&2, RuntimeEvent>
  }
  RuntimeCursorRejected{
    state: RuntimeState,
    diagnostics: List<&2, Effects.EffectDiagnostic>
  }
  RuntimeCursorFault{
    state: RuntimeState,
    reason: Maybe<&2, Rng.RngSampleResult>
  }

def runtime_status(state: RuntimeState) -> Model.BattleStatus:
  match state:
    case RuntimeState{battle, rng, encounter, failed, sources, reservations,
        trapped, defenders, effects}:
      match battle:
        case Model.BattleState{now, wait_ticks, actors, events, sequence,
            status}:
          status

def runtime_cursor_status(
  status: Model.BattleStatus, state: RuntimeState,
  emitted: List<&2, Model.TransitionEvent>,
  combat_events: List<&2, RuntimeEvent>
) -> RuntimeCursor:
  match status:
    case Model.AwaitingCommands{}:
      RuntimeCursorBoundary{state, emitted, combat_events}
    case Model.Victory{}:
      RuntimeCursorTerminal{state, emitted, combat_events}
    case Model.Defeat{}:
      RuntimeCursorTerminal{state, emitted, combat_events}
    case Model.Draw{}:
      RuntimeCursorTerminal{state, emitted, combat_events}
    case Model.Timeout{}:
      RuntimeCursorTerminal{state, emitted, combat_events}
    case Model.Escaped{}:
      RuntimeCursorTerminal{state, emitted, combat_events}
    case Model.SchedulerStalled{}:
      RuntimeCursorStalled{state, emitted, combat_events}
    case Model.Advancing{}:
      RuntimeCursorActive{state, emitted, combat_events}

def runtime_after_step(
  prior_emitted: List<&2, Model.TransitionEvent>,
  prior_combat: List<&2, RuntimeEvent>, result: RuntimeAdvanceResult
) -> RuntimeCursor:
  match result:
    case RuntimeStep{+state, emitted, combat_events}:
      runtime_cursor_status(runtime_status(state), state,
        List.append(&2, Model.TransitionEvent, prior_emitted, emitted),
        List.append(&2, RuntimeEvent, prior_combat, combat_events))
    case RuntimeIdle{state}:
      RuntimeCursorActive{state, prior_emitted, prior_combat}
    case RuntimeEffectRejected{state, diagnostics}:
      RuntimeCursorRejected{state, diagnostics}
    case RuntimeFault{state, reason}:
      RuntimeCursorFault{state, reason}

def runtime_run_one(cursor: RuntimeCursor, ignored: Nat) -> RuntimeCursor:
  match cursor:
    case RuntimeCursorActive{state, emitted, combat_events}:
      runtime_after_step(emitted, combat_events, runtime_step(state))
    case RuntimeCursorBoundary{state, emitted, combat_events}:
      RuntimeCursorBoundary{state, emitted, combat_events}
    case RuntimeCursorTerminal{state, emitted, combat_events}:
      RuntimeCursorTerminal{state, emitted, combat_events}
    case RuntimeCursorStalled{state, emitted, combat_events}:
      RuntimeCursorStalled{state, emitted, combat_events}
    case RuntimeCursorRejected{state, diagnostics}:
      RuntimeCursorRejected{state, diagnostics}
    case RuntimeCursorFault{state, reason}:
      RuntimeCursorFault{state, reason}

def runtime_run_result(cursor: RuntimeCursor) -> RuntimeRunResult:
  match cursor:
    case RuntimeCursorActive{state, emitted, combat_events}:
      RuntimeRunYielded{state, emitted, combat_events}
    case RuntimeCursorBoundary{state, emitted, combat_events}:
      RuntimeRunBoundary{state, emitted, combat_events}
    case RuntimeCursorTerminal{state, emitted, combat_events}:
      RuntimeRunTerminal{state, emitted, combat_events}
    case RuntimeCursorStalled{state, emitted, combat_events}:
      RuntimeRunStalled{state, emitted, combat_events}
    case RuntimeCursorRejected{state, diagnostics}:
      RuntimeRunRejected{state, diagnostics}
    case RuntimeCursorFault{state, reason}:
      RuntimeRunFault{state, reason}

def runtime_run(+fuel: Nat, state: RuntimeState) -> RuntimeRunResult:
  runtime_run_result(List.foldl(~&2, ~Nat, ~RuntimeCursor, ~runtime_run_one,
    List.range(fuel), RuntimeCursorActive{state, Nil{}, Nil{}}))
