import Config

config :multiverses, with_replicant: config_env() != :prod
