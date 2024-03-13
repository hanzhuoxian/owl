package scheme

import "strings"

// GroupKind specifies a Group and a Kind, but does not force a version.  This is useful for identifying
// concepts during lookup stages without having partially valid types.
type GroupKind struct {
	Group string
	Kind  string
}

// Empty return true if group and kine is zero value.
func (gk GroupKind) Empty() bool {
	return gk.Group == "" && gk.Kind == ""
}

// WithVersion fill GroupKind with version.
func (gk GroupKind) WithVersion(version string) GroupVersionKind {
	return GroupVersionKind{Group: gk.Group, Version: version, Kind: gk.Kind}
}

// String defines the string format of GroupKind.
func (gk GroupKind) String() string {
	if gk.Group == "" {
		return gk.Kind
	}

	return gk.Kind + "." + gk.Group
}

// ParseGroupKind parse a string to GroupKind.
func ParseGroupKind(gk string) GroupKind {
	i := strings.Index(gk, ".")
	if i == -1 {
		return GroupKind{Kind: gk}
	}

	return GroupKind{Group: gk[i+1:], Kind: gk[:i]}
}

// GroupResource specifies a Group and a Resource, but does not force a version.  This is useful for identifying
// concepts during lookup stages without having partially valid types.
type GroupResource struct {
	Group    string
	Resource string
}

// WithVersion add version to GroupVersionResource.
func (gr GroupResource) WithVersion(version string) GroupVersionResource {
	return GroupVersionResource{Group: gr.Group, Version: version, Resource: gr.Resource}
}

// Empty return true if Group and Resource both 0.
func (gr GroupResource) Empty() bool {
	return gr.Group == "" && gr.Resource == ""
}

// String defines the string format of GroupResource.
func (gr GroupResource) String() string {
	if gr.Group == "" {
		return gr.Resource
	}

	return gr.Group + "." + gr.Resource
}

// ParseGroupResource turns "resource.group" string into a GroupResource struct.  Empty strings are allowed
// for each field.
func ParseGroupResource(gr string) GroupResource {
	if i := strings.Index(gr, "."); i >= 0 {
		return GroupResource{Group: gr[i+1:], Resource: gr[:i]}
	}

	return GroupResource{Resource: gr}
}

// GroupVersion contains the "group" and the "version", which uniquely identifies the API.
type GroupVersion struct {
	Group   string
	Version string
}

// Empty returns true if group and version are empty.
func (gv GroupVersion) Empty() bool {
	return len(gv.Group) == 0 && len(gv.Version) == 0
}

// String puts "group" and "version" into a single "group/version" string. For the legacy v1
// it returns "v1".
func (gv GroupVersion) String() string {
	if len(gv.Group) > 0 {
		return gv.Group + "/" + gv.Version
	}

	return gv.Version
}

// Identifier implements runtime.GroupVersioner interface.
func (gv GroupVersion) Identifier() string {
	return gv.String()
}

type GroupVersionResource struct {
	Group    string
	Version  string
	Resource string
}

// Empty returns true if GroupVersionResource is 0.
func (gvr GroupVersionResource) Empty() bool {
	return gvr.Group == "" && gvr.Version == "" && gvr.Resource == ""
}

// GroupResource return the group resource of GroupVersionResource.
func (gvr GroupVersionResource) GroupResource() GroupResource {
	return GroupResource{Group: gvr.Group, Resource: gvr.Resource}
}

// GroupVersion return the group version of GroupVersionResource.
func (gvr GroupVersionResource) GroupVersion() GroupVersion {
	return GroupVersion{Group: gvr.Group, Version: gvr.Version}
}

type GroupVersionKind struct {
	Group   string
	Version string
	Kind    string
}
