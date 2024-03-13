// Package scheme defines some useful function for group version.
package scheme

type ObjectKind interface {
	// SetGroupVersionKind sets or clears the intended serialized kind of an object. Passing kind nil
	// should clear the current setting.
	SetGroupVersionKind(gvk GroupVersionKind)
	// GroupVersionKind returns the stored group, version, and kind of an object, or nil if the object does
	// not expose or provide these fields.
	GroupVersionKind() GroupVersionKind
}

type emptyObjectKind struct{}

var EmptyObjectKind = emptyObjectKind{}

// SetGroupVersionKind implements the ObjectKind interface.
func (emptyObjectKind) SetGroupVersionKind(gvk GroupVersionKind) {}

// GroupVersionKind implements the ObjectKind interface.
func (emptyObjectKind) GroupVersionKind() GroupVersionKind { return GroupVersionKind{} }
