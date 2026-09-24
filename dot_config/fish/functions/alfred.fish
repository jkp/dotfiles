function alfred --description 'Talk to Alfred (Letta agent) on orchestra; extra args go to letta, e.g. alfred --new'
    ssh -t orchestra sudo -u containers XDG_RUNTIME_DIR=/run/user/900 \
        podman exec -it alfred letta --agent agent-local-8bf804ca-00b9-4543-9aee-54df1b0a3f91 $argv
end
