# LAN BOOTING
- Make sure the distant machine is setted up to wake on lan
- Use boot init $name to create config file at $HOME/.$name_dist.conf
    replace variables with your own informations
- Run boot $name

## Workflow :
### boot $name :
    Ping $name_ip
        packet received :
            next
        else :
            send wol magic packet
    In range from 1 through $max_try
        Ping $name_ip
            packet received :
                ssh connect
            else :
                continue
### boot init $name :
    Write config file, you need to edit it with your own values.
    args:
        -i enter in interactive mode to make config file faster.
### boot shutdown $name :
    Ping $name_ip
        packet received :
            Execute shutdown command on distant machine
        else :
            // No stand-by detection
            Exit
