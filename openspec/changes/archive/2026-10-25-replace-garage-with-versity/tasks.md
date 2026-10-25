# Tasks

## 1. Versity on TrueNAS (manual, TrueNAS UI)

- [x] 1.1 Create dataset `big-chonk/s3` with `xattr=sa`; verify
      `zfs get xattr big-chonk/s3` shows `sa`
- [x] 1.2 Create a custom app running `versity/versitygw:<pinned version>` with
      `posix /data`, the dataset mounted at `/data`, root access/secret key env
      vars, and port 7070 (or the next free port); verify the app shows Running
- [x] 1.3 From a workstation, run
      `aws --endpoint-url http://10.10.10.100:<port> s3 mb s3://smoke && aws ... s3 cp <file> s3://smoke/ && aws ... s3 ls s3://smoke/`;
      verify the object is listed and appears as a file under the dataset, then
      delete the bucket
- [x] 1.4 Save the root access/secret key in Vaultwarden; each consumer copies
      them into its own Infisical project. Verify the entry exists

## 2. Remove Garage

- [x] 2.1 Confirm with the user that the `test` bucket can be discarded
- [x] 2.2 Delete `apps/apps/templates/garage.yaml` and `garage/`; verify
      `helm template apps/apps | grep -i garage` prints nothing
- [x] 2.3 After the push to `main` syncs, verify `kubectl get ns garage` returns
      NotFound; delete any leftover `garage` PVCs/PVs
- [x] 2.4 Delete the `garage` Infisical project and the `zephyr3-wsl` key's
      local config

## 3. Documentation

- [x] 3.1 Add a bullet to the Deploying section of `AGENTS.md`: S3 endpoint is
      Versity Gateway, a TrueNAS custom app at `http://10.10.10.100:<port>`,
      managed in the TrueNAS UI, path-style only; verify `prek run --all-files`
      passes
