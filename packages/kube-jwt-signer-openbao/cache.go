package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"
)

// cacheFile holds the public keys of the transit key as OpenBao last
// reported them. They are public, but the file is written 0600 anyway: what
// it says decides which tokens the API server accepts.
type cacheFile struct {
	Mount    string          `json:"mount"`
	Key      string          `json:"key"`
	Fetched  time.Time       `json:"fetched"`
	Versions []cachedVersion `json:"versions"`
}

type cachedVersion struct {
	Version int       `json:"version"`
	Created time.Time `json:"creation_time"`
	PKIX    []byte    `json:"pkix"`
}

func saveCache(path, mount, key string, versions []*keyVersion, fetched time.Time) error {
	file := cacheFile{Mount: mount, Key: key, Fetched: fetched}
	for _, v := range versions {
		file.Versions = append(file.Versions, cachedVersion{Version: v.version, Created: v.created, PKIX: v.pkix})
	}
	data, err := json.Marshal(file)
	if err != nil {
		return err
	}

	dir := filepath.Dir(path)
	tmp, err := os.CreateTemp(dir, ".keys-*.json")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	if err := os.Rename(tmp.Name(), path); err != nil {
		return err
	}
	d, err := os.Open(dir)
	if err != nil {
		return err
	}
	defer d.Close()
	return d.Sync()
}

// loadCache returns the cached versions of the key, oldest first. The error
// wraps fs.ErrNotExist when there is no cache.
func loadCache(path, mount, key string) ([]*keyVersion, time.Time, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, time.Time{}, err
	}
	var file cacheFile
	if err := json.Unmarshal(data, &file); err != nil {
		return nil, time.Time{}, fmt.Errorf("%s: %w", path, err)
	}
	if file.Mount != mount || file.Key != key {
		return nil, time.Time{}, fmt.Errorf("%s holds %s/keys/%s, not %s/keys/%s", path, file.Mount, file.Key, mount, key)
	}
	if len(file.Versions) == 0 {
		return nil, time.Time{}, errors.New(path + " holds no versions")
	}
	versions := make([]*keyVersion, 0, len(file.Versions))
	for i, c := range file.Versions {
		if i > 0 && c.Version <= file.Versions[i-1].Version {
			return nil, time.Time{}, fmt.Errorf("%s: versions out of order", path)
		}
		v, err := newKeyVersionPKIX(c.Version, c.Created, c.PKIX)
		if err != nil {
			return nil, time.Time{}, fmt.Errorf("%s: key version %d: %w", path, c.Version, err)
		}
		versions = append(versions, v)
	}
	return versions, file.Fetched, nil
}
