#!/bin/sh

# Create user if USER_NAME is set
if [ ! -z "${USER_NAME}" ]; then
    # Set default values for PUID and PGID if not provided
    PUID=${PUID:-1000}
    PGID=${PGID:-1000}

    # Create group if it doesn't exist
    addgroup -g $PGID $USER_NAME || true
    
    # Create user if it doesn't exist
    adduser -D -H -u $PUID -G $USER_NAME -s /bin/sh $USER_NAME || true

    # Create home directory if it doesn't exist
    mkdir -p /home/$USER_NAME
    chown $USER_NAME:$USER_NAME /home/$USER_NAME

    # Setup sudo access if SUDO_ACCESS is set to 'true'
    if [ "${SUDO_ACCESS}" = "true" ]; then
        echo "$USER_NAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USER_NAME
        chmod 0440 /etc/sudoers.d/$USER_NAME
    fi
fi

# Add public key if PUBLIC_KEY_FILE is set
if [ ! -z "${PUBLIC_KEY_FILE}" ] && [ ! -z "${USER_NAME}" ]; then
    mkdir -p /home/$USER_NAME/.ssh
    cat "${PUBLIC_KEY_FILE}" > /home/$USER_NAME/.ssh/authorized_keys
    chmod 700 /home/$USER_NAME/.ssh
    chmod 600 /home/$USER_NAME/.ssh/authorized_keys
    chown -R $USER_NAME:$USER_NAME /home/$USER_NAME/.ssh
fi

sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Generate host keys if not present
ssh-keygen -A

# Start SSH daemon in the foreground
exec /usr/sbin/sshd -D