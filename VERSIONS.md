# Multiverses versions

## 0.1.0

- initial commit, support for `Multiverses.Registry`

## 0.2.0

- changes the way that items are placed in `Multiverses.Registry`

## 0.3.0

- creates useful helper function to passthrough functions as macros
- creates overloaded `Registry` functions
- allows you to use `:only` parameter to specify which mix environments
  are allowed at compile-time

## 0.4.0

- replaces `:only` activation in favor of using Application settings
- adds support for `GenServer` and `DynamicSupervisor`
- removes nonstandard `Registry` functions
- adds `Multiverses.Registry.via/2` macro.

## 0.4.1

- makes replicants available in the main library so that adapters can
  more easily use them

## 0.4.2

- adds `Multiverses.overrides?/2` for compile-time checking of
  multiverse overridden modules.

## 0.4.3

- adds explicit import statements scoped to the quoted parts

## 0.5.0

- changes GenServer so that it uses the `forward_callers: true` semantic.
- adds Multiverses.Application

## 0.5.1

- silences Multiverses.GenServer dialyzer warnings

## 0.5.2

- adds support for Multiverses.Supervisor

## 0.5.3

- remove stray IO.inspect
- added Multiverses.active? which checks if Multiverses are active.

## 0.6.0

- better no-op condition `use Multiverses` directive
