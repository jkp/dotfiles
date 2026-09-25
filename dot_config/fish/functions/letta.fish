function letta --description 'Letta Code, run inside Alfred'"'"'s container on orchestra (Alfred preset): letta, letta cron list, letta mcp tools actual'
    # Alfred's local backend lives on orchestra (network-config alfred role);
    # the Mac has no agents of its own any more. LETTA_AGENT_ID lets agent-scoped
    # subcommands (cron, mcp, memory, model) work without --agent.
    ssh -t orchestra sudo -u containers XDG_RUNTIME_DIR=/run/user/900 \
        podman exec -it -e LETTA_AGENT_ID=agent-local-8bf804ca-00b9-4543-9aee-54df1b0a3f91 \
        alfred letta $argv
end
