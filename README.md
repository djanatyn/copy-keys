# copy-keys

Given an Ansible inventory path, execute `ssh-copy-id` to transfer public keys to all hosts in a pattern.
Read Ansible inventory files using `ansible-inventory`, and execute `ssh-copy-id` against a set of hosts (in parallel).

# motivation

I'm often encountering new hosts where I don't have my keys copied.

Usually, these are very new (or very old) environments I'm encountering in the context of an Ansible inventory. I can connect to them with a password - but I'd prefer to just use my keys.

You could do this in the shell, using tools like `parallel` and `jq`:
``` sh
parallel -i -j 3 \
  sh -c 'pass show ... | sshpass ssh-copy-id {}' \
  -- $(ansible-inventory -i "$INV_FILE" --list | jq '.GroupPattern.hosts[]' -r)
```

You could also use the `user` module in Ansible, executing directly against the inventory.

I decided to use Haskell as an opportunity to:
* gain more experience scripting in Haskell, and to
* try [`Polysemy`](https://hackage.haskell.org/package/polysemy), an effect handler system.

# scope

This is just intended for me, I don't imagine anyone else would use this package.

You're probably better off using that shell example above.

# in progress

- [X] execute `ansible-inventory` with `typed-process`
- [X] parse `ansible-inventory` JSON using `aeson`
- [X] apply host patterns against `ansible-inventory` output
- [ ] run ssh-copy-id against one host
- [ ] run ssh-copy-id against all hosts returned
- [ ] run ssh-copy-id against all hosts returned, with a worker pool
