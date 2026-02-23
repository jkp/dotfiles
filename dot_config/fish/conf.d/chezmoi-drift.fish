if not status is-interactive && test "$CI" != true
    exit
end
chezmoi-check -q
