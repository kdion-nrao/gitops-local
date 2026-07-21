# Secrets Management

Uses a combination of the following tools for encrypting secrets and using them in the project:
- [helm-secrets](https://github.com/jkroepke/helm-secrets/): Helm plugin for using encrypted fields in Helm charts
- [sops](https://getsops.io/): Encryption/Decryptopn backend chosen for `helm-secrets`
- [age](https://github.com/FiloSottile/age): Encryption tool/key format chosen for `sops`

Note that the choices of `sops` and `age` are not the only available options for a solution using `helm-secrets`, but were chosen for simplicity and ease of use.

## `age` Keys

One of the interesting things about `age` encryption keys is that the tool supports using SSH keys (`ssh-ed25519` and `ssh-rsa` only), so in theory key management for `sops` could use existing SSH key distribution mechanisms and channels. 

In this vein, this prototype generates the list of age 'recipients` (public keys which can decrypt a given file) using SSH public keys gathered from GitHub via a list of usernames:

- `.sops.users`: contains a list of GitHub usernames to allow, one per line
- `sops_gen_recipients.sh`: Reads the `.sops.users` file, and for each username:
   - Pulls public SSH keys from https://github.com/<username>.keys
   - For each `ssh-ed25519` or `ssh-rsa` key, adds it to the key list in `.sops.recipients`
   - Adds all keys in `.sops.recipients` to the `.sops.yaml` configuration file using `yq`
   - Re-encrypts all secrets files under `secrets/` with the latest keys

## Encrypting/Decrypting secrets files

For this prototype, all sensitive data is located under the `secrets/` directory, and a corresponding configuration in `.sops.yaml` has been added to set which keys to use. 

Rules for `.gitignore` have been added to help prevent unencrypted sensitive data from being uploaded into the public repository, with unencrypted files using a plain `*.yaml` naminc convention, with the encrypted version using a `*.enc.yaml` extension.

To encrypt a plaintext yaml file, you would run the following:
```bash
sops -e secrets/test.yaml > secrets/test.enc.yaml
```

To decrypt the encrypted file, you would run
```bash
sops -d secrets/test.enc.yaml > secrets/test.yaml
```

When the key list is updated, you can re-encrypt the file with the new keys list by running:
```bash
sops updatekeys secrets/test.enc.yaml
```
