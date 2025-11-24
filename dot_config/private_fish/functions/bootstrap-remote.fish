function bootstrap-remote
    ssh $argv[1] "curl -fsSL https://raw.githubusercontent.com/jkp/dotfiles/main/bootstrap.sh | bash"
end
