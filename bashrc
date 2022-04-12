# .bashrc

# some SGR (Select Graphic Rendition) escape codes
# see: http://en.wikipedia.org/wiki/ANSI_escape_code

# styles
NORMAL="\e[0m"
BOLD="\e[1m"
FAINT="\e[2m"
ITALIC="\e[3m"
UNDERLINE="\e[4m"
# foreground colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
WHITE="\e[37m"
# background colors
BG_RED="\e[41m"
BG_GREEN="\e[42m"
BG_YELLOW="\e[43m"
BG_BLUE="\e[44m"
BG_MAGENTA="\e[45m"
BG_CYAN="\e[46m"
BG_WHITE="\e[47m"
# style/color reset
NC="\e[0m"
RESET=$NC
# export all the SGR codes
export NORMAL BOLD FAINT ITALIC UNDERLINE RED GREEN YELLOW BLUE MAGENTA CYAN WHITE BG_RED BG_GREEN BG_YELLOW BG_BLUE BG_MAGENTA BG_CYAN BG_WHITE NC RESET

# User specific aliases and functions

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias la='ls -alhF'
alias findcur='find . -iname'

alias drm='docker rm -f'
alias dps='docker ps -a'

# rook tool box
alias rook_tool_box='kubectl -n rook-ceph exec daemonset/rook-ceph-tools -it -- bash'

alias tolower='tr "[:upper:]" "[:lower:]"'
alias toupper='tr "[:lower:]" "[:upper:]"'

alias hexcalc='calc -i 16 -o 16 "$@"'
alias octcalc='calc -i 8 -o 8 "$@"'
alias dec2hex='calc -i 10 -o 16 "$@"'
alias hex2dec='calc -i 16 -o 10 "$@"'
alias dec2oct='calc -i 10 -o 8 "$@"'
alias oct2dec='calc -i 8 -o 10 "$@"'
alias iecfmt='numfmt --from=iec --to=iec --'

alias alterlined='blanklined -b 0 -c BLUE'

# Source global definitions

if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

export HISTCONTROL=ignorespace:erasedups

# the PROMPT
PS1='\[\e[0;2;32m\]\u@\h ''\[\e[2;34m\]\w\n''\[\e[0;1;37m\]\$''\[\e[0m\] '

source /usr/share/bash-completion/helpers/complete_alias


if which git &> /dev/null; then
    alias g='git'
    complete -F _complete_alias g
fi

if which helm &> /dev/null; then
    source <(helm completion bash)
fi


if which kubectl &> /dev/null; then
    source <(kubectl completion bash)
    alias k=kubectl
    complete -F _complete_alias k
    complete -F __complete_k_namespaces k_switch_namespace
    complete -F __complete_k_namespaces k_remaining_resoures
    complete -F __complete_k_pods k_pod_bash
    complete -F __complete_k_finalize k_finalize
fi

if [ -f /usr/share/bash-completion/completions/docker ]; then
    source /usr/share/bash-completion/completions/docker
    alias d=docker
    complete -F _complete_alias d
    complete -F __complete_d_containers drm
    complete -F __complete_d_images d_push_to_registry
    complete -F __complete_d_images d_retag
fi


function sendmsg(){
    if [[ $1 == "" ]] ; then
        echo -e "Usage: sendmsg <pts-number> <text>\n"
        return
    fi;
    echo -e "\n${2}\n" | write root pts/${1}
}


function calc(){
    # bc 命令便捷包装函数。
    # 方便指定输入、输出进制、小数位数（默认为10）
    if [[ -z $1 ]]; then
        cat <<-EOF
		Usage: calc <expression> [-p <digits>] [-i <input-base>] [-o <output-base>]\n"
		Examples:
		    calc  "(8+3)/3"
		    calc  7^23
		    calc  "1024*1024"  -i 10 -o 16
		    calc  ABC  -i 16 -o 10
		EOF
        return 1
    fi
    local expressions='' scale=10; ib=10; ob=10;

    while true ; do
        if [[ $1 == "-p" || $1 == "--precision" ]]; then
            scale=$2
            shift 2
        elif [[ $1 == "-i" || $1 == "--input-base" ]]; then
            ib=$2
            shift 2
        elif [[ $1 == "-o" || $1 == "--output-base" ]]; then
            ob=$2
            shift 2
        else
            expressions+=" ${1^^}"
            shift 1
        fi
        if [[ $1 == "" ]]; then
            break
        fi
    done
    
    if [ -z "$expressions" ]; then
        expressions='0'
    fi

    cat <<-EOF | bc -l | sed 's|^\(-*\)\.|\10.|'
	obase=${ob};
	ibase=${ib};
	scale=${scale};
	x=${expressions};
	x;
	EOF
}


# completion functions

function __complete_d_images(){
    _get_comp_words_by_ref -n : cur
    __docker_complete_images --force-tag
}

function __complete_d_containers(){
    _get_comp_words_by_ref -n : cur
    __docker_complete_containers --name -a
}

function __complete_k_namespaces(){
    _get_comp_words_by_ref -n : cur
    COMPREPLY=( $(compgen -W "$(kubectl get ns -o jsonpath='{.items[*].metadata.name}')" -- "$cur") )
}

function __complete_k_pods(){
    _get_comp_words_by_ref -n : cur
    COMPREPLY=( $(compgen -W "$(kubectl get pods -o jsonpath='{.items[*].metadata.name}')" -- "$cur") )
}

function __complete_k_finalize(){
    local cur prev words cword
    local kubectl_out
    COMPREPLY=()
    _get_comp_words_by_ref -n := cur prev words cword

    if [ $cword -eq 1 ]; then
        kubectl_out=$(kubectl api-resources --cached --request-timeout=1s --verbs=list -o name)
    elif [ $cword -eq 2 ]; then
        kubectl_out=$(kubectl get -o template --template="{{ range .items  }}{{ .metadata.name }} {{ end }}" $prev)
    fi

    [ -n "$kubectl_out" ] && COMPREPLY=( $( compgen -W "${kubectl_out[*]}" -- "$cur" ) )
}

# kubectl quick functions

function k_recreate(){
    # delete resource defined in file $1, and create it again
    if [[ $1 == "" ]] ; then
        echo -e "Usage: k_recreate <yaml-file>\n"
        return
    fi;
    kubectl delete -f $1
    kubectl create -f $1
}

function k_switch_namespace(){
    # switch namespace
    if [[ $1 == "" ]] ; then
        echo -e "Usage: k_switch_namespace <namespace>\n"
        return
    fi;
    kubectl config set-context --current --namespace=$1
}

function k_remaining_resoures(){
    if [ -z "$1" ]; then
        echo "Usage: k_remaining_resoures <namespace>"
        return 1
    fi

    local ns=$1
    kubectl api-resources --verbs=list --namespaced -o name \
    | xargs -n 1 kubectl get --show-kind --ignore-not-found -n $ns \
    | while read line ; do
        name=$( echo $line | cut -d ' ' -f 1 )
        if [[ $name = NAME || $name = LAST || $name =~ [0-9]+.+ ]]; then continue; fi
        echo $name
    done
}

function k_finalize(){
    # remove finalizers for resource $* and delete it. 
    if [[ -z $1 ]]; then
        cat <<-EOF
		Usage: k_finalize  < resource_kind/resource_name | <resource_kind> <resource_name> >
		Example:
		    k_finalize  deployment/nginx
		    k_finalize  pod nginx-pod
		EOF
        return 1
    fi

    local res=$*
    kubectl patch --type merge -p '{"metadata":{"finalizers": []}}' $res
    kubectl delete $res
}

function k_pod_bash(){
    if [[ $1 == "" ]] ; then
        echo -e "Usage: k_pod_bash <pod-name>\n"
        return
    fi;
    pod=$1
    shift
    kubectl exec -it $pod -- bash $*
}

# docker quick funcitons

export MY_DOCKER_REGISTRY_URL=10.10.8.45:5000

function d_add_insecure_registry(){
    if [[ $1 == "" ]] ; then
        echo -e "Usage: d_add_insecure_registry <server-ip:server-port>\n"
        return
    fi;
    
    server=$1
    conf='/etc/docker/daemon.json'
    
    cat $conf | jq '.+ {"insecure-registries": (."insecure-registries" + ["'$server'"] | unique )}' > _daemon.json
    # I dont know why redircting to $conf gets an empty file.
    mv -f _daemon.json $conf

    # sudo systemctl daemon-reload
    sudo systemctl restart docker
}

function d_add_registry_mirror(){
    if [[ $1 == "" ]] ; then
        echo -e "Usage: d_add_registry_mirror <server-ip:server-port>\n"
        return
    fi;
    
    server=$1
    conf='/etc/docker/daemon.json'
    
    cat $conf | jq '.+ {"registry-mirrors": (."registry-mirrors" + ["'$server'"] | unique )}' > _daemon.json
    # I dont know why redircting to $conf gets an empty file.
    mv -f _daemon.json $conf

    # sudo systemctl daemon-reload
    sudo systemctl restart docker
}

function d_pull_from_registry(){
    if [[ $1 == "" ]] ; then
        echo -e "Usage: d_pull_from_registry  [-r <registry-url>]  <image-tag>  [<image-tag>...]\n"
        return
    fi;

    local registry_url
    local image_tags=()
    # iterate arguments
    while true ; do
        if [[ $1 == "-r" ]]; then
            registry_url=$2
            shift 2
        else
            image_tags+=($1)
            shift 1
        fi
        if [[ $1 == "" ]]; then
            break
        fi
    done
    
    if [ -z "$registry_url" ]; then
        echo -e "$YELLOW No registry url provided, defaulting to $MY_DOCKER_REGISTRY_URL $NC"
        registry_url=$MY_DOCKER_REGISTRY_URL
    fi

    local i=0
    for tag in "${image_tags[@]}"; do
        ((i++))
        echo -e "\n$BOLD------------------------------------- $i/${#image_tags[@]} $NC"

        IFS='/' read -ra tag_array <<< "$tag"
        set -- "${tag_array[@]}"
        [[ $# == 1 ]] && set -- library $@
        # [[ $# == 2 ]]
        [[ $# == 3 ]] && shift 1

        new_tag=$registry_url/$1/$2

        echo -e "$YELLOW Pulling image $1/$2 from registry $registry_url $NC"
        docker pull $new_tag
        
        echo "Re-tag image $new_tag to $tag"
        d_retag $new_tag $tag
    done
}

function d_push_to_registry() {
    if [[ $1 == "" ]]; then
        echo "Usage: d_push_to_registry [-r <registry-url>]  <image-tag>  [<image-tag>...] "
        return 1
    fi

    local registry_url
    local image_tags=()
    # iterate arguments
    while true ; do
        if [[ $1 == "-r" ]]; then
            registry_url=$2
            shift 2
        else
            image_tags+=($1)
            shift 1
        fi
        if [[ $1 == "" ]]; then
            break
        fi
    done
    
    if [ -z "$registry_url" ]; then
        echo -e "$YELLOW No registry url provided, defaulting to $MY_DOCKER_REGISTRY_URL $NC"
        registry_url=$MY_DOCKER_REGISTRY_URL
    fi

    local tag
    local i=0
    for tag in "${image_tags[@]}"; do
        ((i++))
        echo -e "\n$BOLD------------------------------------- $i/${#image_tags[@]} $NC"

        #   pull image if not present on local machine
        if [ "$(docker images -q $tag 2> /dev/null)" == "" ]; then
            echo -e "$YELLOW Pulling image $tag $NC"
            docker pull $tag
        fi

        IFS='/' read -ra tag_array <<< "$tag"
        set -- "${tag_array[@]}"
        [[ $# == 1 ]] && set -- library $@
        # [[ $# == 2 ]]
        [[ $# == 3 ]] && shift 1

        new_tag=$registry_url/$1/$2
        # echo $new_tag

        docker tag $tag $new_tag
        
        echo -e "$YELLOW Pushing image $1/$2 to registry $registry_url $NC"
        docker push $new_tag

        echo -e " Deleting local tag $new_tag"
        docker rmi $new_tag
    done
    echo -e "$YELLOW Done with $tag $NC"
}

function d_retag() {
    local image=$1
    local new_tag=$2
    
    # require 2 arguments
    if [ $# -ne 2 ]; then
        echo "usage: d_retag <image> <new-tag>"
        return 1
    fi
    
    # check if image exists
    if ! docker images | grep -q ${image%:*}; then
        echo "image $image does not exist"
        return 1
    fi
    docker tag $image $new_tag
    docker rmi $image
}

function find_container_by_pid() {
    pid=$1
    if [ -z "$pid" ]; then
        echo "Usage: find_container_by_pid  <PID-from-host> [-q]"
        echo "  -q: quiet mode. show container id only."
        return -1
    fi

    for containerId in $(docker ps -q); do
        docker top $containerId | grep $pid >/dev/null
        if [ $? -eq 0 ]; then
            if [[ "$*" =~ "-q" ]]; then
                result=$(docker ps --filter ID=$containerId --format '{{.ID}}')
                echo $result
            else
                result=$(docker ps --filter ID=$containerId --format '{{.ID}} {{.Names}}')
                printf "%12s %s\n" ID Name
                echo $result
            fi
            return 0
        fi
    done
    return 2
}

# function d_search_hash () {
d_search_hash () {
    if [ -t 1 ]; then
       local result=$(_d_search_hash "$@" | column -t)
       echo -en $BOLD
       echo "$result" | head -n 1
       echo -en $NC
       echo "$result" | tail -n-2 | blanklined -b 0 -c BLUE
    else
       _d_search_hash "$@" | column -t
    fi
}

function _d_search_hash () {
    if [ -z "$1" ]; then
	echo "Usage: d_search_hash  <any-hash-string>"
	echo "Example: d_search_hash  ef68cd3"
	return 1
    fi
    
    local hash=$1
    local found=()
    for i in $(docker container ls -q); do
        if docker inspect $i | grep --color=never $hash > /dev/null; then
            found+=($i);
        fi;
    done
    if [[ ${#found[@]} -eq 0 ]]; then
	echo Nothing found.
	return 1
    fi
    
    echo -e "ContainerID\t ContainerName\t ImageID\t ImageName"
    for i in "${found[@]}"; do
	local s=$(docker inspect $i | jq -r '.[0]')
	local ContainerID=$(echo $s | jq -r '.Id')
	local ContainerName=$(echo $s | jq -r '.Name')
	local ImageID=$(echo $s | jq -r '.Image')
	local ImageName=$(docker inspect $ImageID | jq -r '.[0] | .RepoTags[0]')
	echo -e "$ContainerID\t $ContainerName\t $ImageID\t $ImageName"
    done
}


# misc functions

function blanklined(){
    local bg_color fg_color reset=$NC blank_lines=1
    while true ; do
        if [[ $1 == "--help" || $1 == "-h" ]]; then
            echo -e "Usage: blank_lined [--help] [-b <blank-lines>] [--bg <color>] [--fg <color>] [-l <max-lines>]\n"
            echo -e "  --help, -h: print this help message"
            echo -e "  -c <color>, --fg <color>, --color <color>: foreground color"
            echo -e "  --bg <color>: background color"
            echo -e "  -b <blank-lines>: number of blank lines to print"
            echo -e "  -l <max-lines>: maximum number of lines to print"
            return
        fi
        if [[ $1 == "-c" || $1 == "--color" || $1 == "--fc" || $1 == "--fg-color" ]]; then
            fg_color=$2
            eval fg_color=\$$fg_color
            shift 2
        fi
        if [[ $1 == "--bc" || $1 == "--bg-color" ]]; then
            bg_color=$2
            eval bg_color=\$$bg_color
            shift 2
        fi
        if [[ $1 == "-l" || $1 == "--lines" ]]; then
            max_lines=$2
            shift 2
        fi
        if [[ $1 == "-b" || $1 == "--blank" ]]; then
            blank_lines=$2
            shift 2
        fi
        if [[ $1 == "" ]]; then
            break
        fi
    done

    if [[ -z "$fg_color" && -z "$bg_color" ]]; then
        reset=""
    fi

    local colored=1 lines=0
    while read line; do
        if [[ $colored == 1 ]]; then
            echo -e "$bg_color$fg_color$line$reset"
        else
            echo -e "$line"
        fi
        for ((i=0; i<$blank_lines; i++)); do echo; done
        
        ((colored ^= 1))
        ((lines++))
        if [[ $max_lines != "" && $lines -ge $max_lines ]]; then
            break
        fi
    done
}


export -f \
    calc \
    d_pull_from_registry \
    d_push_to_registry \
    d_retag \
    find_container_by_pid \
    d_search_hash \
    blanklined


# other scripts
[ -d ~/.scripts ]&& {
    for f in $(find ~/.scripts -name "*.sh"); do
        source $f
    done
}
