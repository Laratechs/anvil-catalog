// Package catalog embeds Anvil's default catalog, which a server uses when
// ANVIL_CATALOG is not set, so "anvil server" works with no other checkout.
//
// The files beside this one are an ordinary catalog (see internal/catalog):
// the Laratechs service, GCP and AWS definitions and their Terraform
// modules. Production servers should still pin a catalog revision with
// ANVIL_CATALOG; this one changes whenever Anvil is upgraded.
package catalog

import (
	"crypto/sha256"
	"embed"
	"encoding/hex"
	"io/fs"
	"os"
	"path/filepath"
)

// Files holds the catalog.
//
//go:embed catalog.hcl definitions components
var Files embed.FS

// Revision identifies the embedded content: "builtin-" and the start of a
// hash over every file, so a change to the catalog is visible on services
// even when the Anvil version is not.
func Revision() string {
	h := sha256.New()
	_ = fs.WalkDir(Files, ".", func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		b, err := Files.ReadFile(path)
		if err != nil {
			return err
		}
		h.Write([]byte(path + "\x00"))
		h.Write(b)
		return nil
	})
	return "builtin-" + hex.EncodeToString(h.Sum(nil))[:12]
}

// Extract writes the catalog to dir, replacing what an earlier version
// left there.
func Extract(dir string) error {
	if err := os.RemoveAll(dir); err != nil {
		return err
	}
	return fs.WalkDir(Files, ".", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		dst := filepath.Join(dir, filepath.FromSlash(path))
		if d.IsDir() {
			return os.MkdirAll(dst, 0o750)
		}
		b, err := Files.ReadFile(path)
		if err != nil {
			return err
		}
		return os.WriteFile(dst, b, 0o600)
	})
}
