# copy-keys

Given:
* a path to an Ansible inventory file, and 
* a pattern,

execute `ssh-copy-id` to transfer public keys to matching hosts.

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

# usage

``` haskell
data Hosts pat where
  Hosts :: KnownSymbol pat => {hosts :: Maybe [Value]} -> Hosts pat
```

``` haskell
*CopyKeys> inv <- runM . librarianIO $ readInventory "./example-inventory.yaml"
*CopyKeys> decode @(Hosts "ExampleGroup") inv
Just (Hosts {hosts = Just [String "example-host1.com",String "example-host2.com"]})
*CopyKeys> :t decode @(Hosts "ExampleGroup") inv
decode @(Hosts "ExampleGroup") inv :: Maybe (Hosts "ExampleGroup")
```

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
