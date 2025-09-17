package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// VPNServerSpec defines the desired state of VPNServer
type VPNServerSpec struct {
	// Replicas is the number of VPN server replicas
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=10
	Replicas int32 `json:"replicas"`

	// Image is the VPN server image
	Image string `json:"image"`

	// Port is the VPN server port
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=65535
	Port int32 `json:"port"`

	// Interface is the WireGuard interface name
	Interface string `json:"interface"`

	// Address is the VPN server address
	Address string `json:"address"`

	// DNS is the DNS server for VPN clients
	DNS string `json:"dns"`

	// AllowedIPs is the allowed IPs for VPN clients
	AllowedIPs string `json:"allowedIPs"`

	// Resources defines the resource requirements
	Resources ResourceRequirements `json:"resources,omitempty"`

	// NodeSelector defines node selection constraints
	NodeSelector map[string]string `json:"nodeSelector,omitempty"`

	// Tolerations defines pod tolerations
	Tolerations []Toleration `json:"tolerations,omitempty"`

	// Affinity defines pod affinity rules
	Affinity *Affinity `json:"affinity,omitempty"`
}

// VPNServerStatus defines the observed state of VPNServer
type VPNServerStatus struct {
	// Replicas is the current number of replicas
	Replicas int32 `json:"replicas"`

	// ReadyReplicas is the number of ready replicas
	ReadyReplicas int32 `json:"readyReplicas"`

	// AvailableReplicas is the number of available replicas
	AvailableReplicas int32 `json:"availableReplicas"`

	// Conditions represent the latest available observations
	Conditions []Condition `json:"conditions,omitempty"`

	// PublicKey is the VPN server public key
	PublicKey string `json:"publicKey,omitempty"`

	// Endpoint is the VPN server endpoint
	Endpoint string `json:"endpoint,omitempty"`

	// ConnectedClients is the number of connected clients
	ConnectedClients int32 `json:"connectedClients,omitempty"`

	// TotalTraffic is the total traffic in bytes
	TotalTraffic int64 `json:"totalTraffic,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:printcolumn:name="Replicas",type="integer",JSONPath=".status.replicas"
// +kubebuilder:printcolumn:name="Ready",type="integer",JSONPath=".status.readyReplicas"
// +kubebuilder:printcolumn:name="Age",type="date",JSONPath=".metadata.creationTimestamp"

// VPNServer is the Schema for the vpnservers API
type VPNServer struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   VPNServerSpec   `json:"spec,omitempty"`
	Status VPNServerStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

// VPNServerList contains a list of VPNServer
type VPNServerList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []VPNServer `json:"items"`
}

// ResourceRequirements defines resource requirements
type ResourceRequirements struct {
	Limits   ResourceList `json:"limits,omitempty"`
	Requests ResourceList `json:"requests,omitempty"`
}

// ResourceList defines resource quantities
type ResourceList struct {
	CPU    string `json:"cpu,omitempty"`
	Memory string `json:"memory,omitempty"`
}

// Toleration defines pod toleration
type Toleration struct {
	Key      string `json:"key,omitempty"`
	Operator string `json:"operator,omitempty"`
	Value    string `json:"value,omitempty"`
	Effect   string `json:"effect,omitempty"`
}

// Affinity defines pod affinity rules
type Affinity struct {
	NodeAffinity    *NodeAffinity    `json:"nodeAffinity,omitempty"`
	PodAffinity     *PodAffinity     `json:"podAffinity,omitempty"`
	PodAntiAffinity *PodAntiAffinity `json:"podAntiAffinity,omitempty"`
}

// NodeAffinity defines node affinity rules
type NodeAffinity struct {
	RequiredDuringSchedulingIgnoredDuringExecution *NodeSelector `json:"requiredDuringSchedulingIgnoredDuringExecution,omitempty"`
}

// NodeSelector defines node selection constraints
type NodeSelector struct {
	NodeSelectorTerms []NodeSelectorTerm `json:"nodeSelectorTerms"`
}

// NodeSelectorTerm defines node selection term
type NodeSelectorTerm struct {
	MatchExpressions []NodeSelectorRequirement `json:"matchExpressions,omitempty"`
}

// NodeSelectorRequirement defines node selector requirement
type NodeSelectorRequirement struct {
	Key      string   `json:"key"`
	Operator string   `json:"operator"`
	Values   []string `json:"values,omitempty"`
}

// PodAffinity defines pod affinity rules
type PodAffinity struct {
	RequiredDuringSchedulingIgnoredDuringExecution []PodAffinityTerm `json:"requiredDuringSchedulingIgnoredDuringExecution,omitempty"`
}

// PodAntiAffinity defines pod anti-affinity rules
type PodAntiAffinity struct {
	RequiredDuringSchedulingIgnoredDuringExecution []PodAffinityTerm `json:"requiredDuringSchedulingIgnoredDuringExecution,omitempty"`
}

// PodAffinityTerm defines pod affinity term
type PodAffinityTerm struct {
	LabelSelector *LabelSelector `json:"labelSelector,omitempty"`
	Namespaces    []string       `json:"namespaces,omitempty"`
	TopologyKey   string         `json:"topologyKey"`
}

// LabelSelector defines label selection
type LabelSelector struct {
	MatchLabels      map[string]string          `json:"matchLabels,omitempty"`
	MatchExpressions []LabelSelectorRequirement `json:"matchExpressions,omitempty"`
}

// LabelSelectorRequirement defines label selector requirement
type LabelSelectorRequirement struct {
	Key      string   `json:"key"`
	Operator string   `json:"operator"`
	Values   []string `json:"values,omitempty"`
}

// Condition defines a condition
type Condition struct {
	Type               string      `json:"type"`
	Status             string      `json:"status"`
	LastTransitionTime metav1.Time `json:"lastTransitionTime"`
	Reason             string      `json:"reason,omitempty"`
	Message            string      `json:"message,omitempty"`
}

func init() {
	SchemeBuilder.Register(&VPNServer{}, &VPNServerList{})
}






