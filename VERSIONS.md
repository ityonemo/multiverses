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
