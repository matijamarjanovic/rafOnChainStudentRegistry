package raf

import (
        "errors"
        "std"
        "strings"

        "gno.land/p/demo/avl"
        "gno.land/p/demo/grc/grc721"
        "gno.land/p/demo/ufmt"
)

// Error definitions
var (
        ErrUnauthorized          = errors.New("caller is not authorized")
        ErrInvalidEmail          = errors.New("invalid school email domain")
        ErrEmailExists           = errors.New("email already registered")
        ErrStudentIDExists       = errors.New("student ID already exists")
        ErrInvalidStudent        = errors.New("student not found")
        ErrAlreadyGraduated      = errors.New("student already graduated")
        ErrAdminExists           = errors.New("admin already exists")
        ErrAdminNotFound         = errors.New("admin not found")
        ErrCannotRemoveLastAdmin = errors.New("cannot remove last admin")
)

// StudentInfo represents the metadata for each Student NFT
type StudentInfo struct {
        FullName        string
        DateOfBirth     string
        Email           string // school-issued email (@raf.rs)
        StudentID       string // unique student identifier
        EnrolledAt      string
        GraduatedAt     *string // nil if still enrolled
        Department      string  // e.g., "Software Engineering", "Computer Science"
        Year            uint8   // current year of study
        ImageURL        string  // URL of the student NFT image
        Status          string  // "Active", "Graduated", "Academic Probation"
        ProbationReason string  // Reason for academic probation, if any
}

// RAFStudentRegistry manages the student NFT collection
type RAFStudentRegistry struct {
        name           string   // "RAF Student Registry"
        symbol         string   // "RAFSR"
        students       avl.Tree // tokenId -> StudentInfo
        owners         avl.Tree // tokenId -> student address
        emailIndex     avl.Tree // email -> tokenId (for uniqueness check)
        studentIDIndex avl.Tree // studentID -> tokenId (for uniqueness check)
        admins         avl.Tree // address -> bool (for admin status)
        tokenURIs      avl.Tree // tokenId -> URI
}

// Ensure RAFStudentRegistry implements GRC721
var _ grc721.IGRC721 = (*RAFStudentRegistry)(nil)

// Initialize registry with first admin
func NewRAFStudentRegistry(firstAdmin std.Address) *RAFStudentRegistry {
        r := &RAFStudentRegistry{
                name:   "RAF Student Registry",
                symbol: "RAFSR",
        }
        r.admins.Set(string(firstAdmin), true)
        return r
}

// Check if address is admin
func (r *RAFStudentRegistry) IsAdmin(addr std.Address) bool {
        isAdmin, exists := r.admins.Get(string(addr))
        return exists && isAdmin.(bool)
}

// Add new admin (only callable by existing admin)
func (r *RAFStudentRegistry) AddAdmin(newAdmin std.Address) error {
        caller := std.GetOrigCaller()
        if !r.IsAdmin(caller) {
                return ErrUnauthorized
        }

        if _, exists := r.admins.Get(string(newAdmin)); exists {
                return ErrAdminExists
        }

        r.admins.Set(string(newAdmin), true)

        std.Emit(ufmt.Sprintf("admin_added:by=%s:new_admin=%s",
                string(caller),
                string(newAdmin),
        ))

        return nil
}

// Remove admin (only callable by existing admin)
func (r *RAFStudentRegistry) RemoveAdmin(admin std.Address) error {
        caller := std.GetOrigCaller()
        if !r.IsAdmin(caller) {
                return ErrUnauthorized
        }

        if caller == admin {
                return errors.New("cannot remove self as admin")
        }

        if _, exists := r.admins.Get(string(admin)); !exists {
                return ErrAdminNotFound
        }

        var adminCount int
        r.admins.Iterate("", "", func(key string, value interface{}) bool {
                adminCount++
                return false
        })
        if adminCount <= 1 {
                return ErrCannotRemoveLastAdmin
        }

        r.admins.Remove(string(admin))

        std.Emit(ufmt.Sprintf("admin_removed:by=%s:removed_admin=%s",
                string(caller),
                string(admin),
        ))

        return nil
}

func (r *RAFStudentRegistry) BalanceOf(owner std.Address) (uint64, error) {
        var balance uint64
        r.owners.Iterate("", "", func(key string, value interface{}) bool {
                if value.(std.Address) == owner {
                        balance++
                }
                return false
        })
        return balance, nil
}

func (r *RAFStudentRegistry) OwnerOf(tid grc721.TokenID) (std.Address, error) {
        owner, exists := r.owners.Get(string(tid))
        if !exists {
                return "", grc721.ErrInvalidTokenId
        }
        return owner.(std.Address), nil
}

func (r *RAFStudentRegistry) TransferFrom(from, to std.Address, tid grc721.TokenID) error {
        // Students cannot transfer their NFTs - they are bound to their identity
        return errors.New("student NFTs are non-transferable")
}

func (r *RAFStudentRegistry) SafeTransferFrom(from, to std.Address, tid grc721.TokenID) error {
        // Students cannot transfer their NFTs - they are bound to their identity
        return errors.New("student NFTs are non-transferable")
}

func (r *RAFStudentRegistry) Approve(approved std.Address, tid grc721.TokenID) error {
        // No approval needed as NFTs are non-transferable
        return errors.New("student NFTs cannot be approved for transfer")
}

func (r *RAFStudentRegistry) GetApproved(tid grc721.TokenID) (std.Address, error) {
        return "", errors.New("student NFTs do not support approvals")
}

func (r *RAFStudentRegistry) IsApprovedForAll(owner, operator std.Address) bool {
        return false
}

func (r *RAFStudentRegistry) SetApprovalForAll(operator std.Address, approved bool) error {
        return errors.New("student NFTs do not support operator approvals")
}

// SetTokenURI sets the token URI for a student NFT (only callable by token owner)
func (r *RAFStudentRegistry) SetTokenURI(tid grc721.TokenID, tURI grc721.TokenURI) (bool, error) {
        // Check if token exists
        owner, err := r.OwnerOf(tid)
        if err != nil {
                return false, grc721.ErrInvalidTokenId
        }

        // Check if caller is the token owner
        if std.GetOrigCaller() != owner {
                return false, grc721.ErrCallerIsNotOwner
        }

        // Set the token URI
        r.tokenURIs.Set(string(tid), string(tURI))
        return true, nil
}

// TokenURI returns the URI for a given token ID
func (r *RAFStudentRegistry) TokenURI(tid grc721.TokenID) (string, error) {
        // Check if token exists
        if _, err := r.OwnerOf(tid); err != nil {
                return "", grc721.ErrInvalidTokenId
        }

        // Get the token URI
        uri, exists := r.tokenURIs.Get(string(tid))
        if !exists {
                return "", nil // Return empty string if URI is not set
        }

        return uri.(string), nil
}

// IssueStudentNFT creates a new student NFT (only callable by admin)
func (r *RAFStudentRegistry) IssueStudentNFT(
        studentAddr std.Address,
        info StudentInfo,
) (grc721.TokenID, error) {
        if !r.IsAdmin(std.GetOrigCaller()) {
                return "", ErrUnauthorized
        }

        if !strings.HasSuffix(info.Email, "@raf.rs") {
                return "", ErrInvalidEmail
        }

        if _, exists := r.emailIndex.Get(info.Email); exists {
                return "", ErrEmailExists
        }

        if _, exists := r.studentIDIndex.Get(info.StudentID); exists {
                return "", ErrStudentIDExists
        }

        tokenId := grc721.TokenID(info.StudentID)

        // Set the image URL
        info.ImageURL = "https://elab.fon.bg.ac.rs/wp-content/uploads/2014/03/raf1.png"

        // Store student info and indexes
        r.students.Set(string(tokenId), info)
        r.owners.Set(string(tokenId), studentAddr)
        r.emailIndex.Set(info.Email, tokenId)
        r.studentIDIndex.Set(info.StudentID, tokenId)

        // Emit transfer event as a string
        std.Emit(ufmt.Sprintf("Transfer:from=%s:to=%s:tokenId=%s",
                "", // empty string for minting
                string(studentAddr),
                string(tokenId),
        ))

        return tokenId, nil
}

// UpdateStudentYear updates student's current year (only callable by admin)
func (r *RAFStudentRegistry) UpdateStudentYear(
        tokenId grc721.TokenID,
        newYear uint8,
) error {
        if !r.IsAdmin(std.GetOrigCaller()) {
                return ErrUnauthorized
        }

        info, exists := r.students.Get(string(tokenId))
        if !exists {
                return ErrInvalidStudent
        }

        studentInfo := info.(StudentInfo)
        if studentInfo.GraduatedAt != nil {
                return ErrAlreadyGraduated
        }

        studentInfo.Year = newYear
        r.students.Set(string(tokenId), studentInfo)

        std.Emit(ufmt.Sprintf("student_year_updated:tokenId=%s:year=%d",
                string(tokenId),
                newYear,
        ))

        return nil
}

// GraduateStudent marks a student as graduated and transfers NFT back to registry
func (r *RAFStudentRegistry) GraduateStudent(tokenId grc721.TokenID) error {
        if !r.IsAdmin(std.GetOrigCaller()) {
                return ErrUnauthorized
        }

        info, exists := r.students.Get(string(tokenId))
        if !exists {
                return ErrInvalidStudent
        }

        studentInfo := info.(StudentInfo)
        if studentInfo.GraduatedAt != nil {
                return ErrAlreadyGraduated
        }

        if studentInfo.Year != 4 {
                return errors.New("student must be in final year to graduate")
        }

        // Update graduation status
        currentHeight := std.GetHeight().String()
        studentInfo.GraduatedAt = &currentHeight
        studentInfo.Status = "Graduated"

        // Store updated info
        r.students.Set(string(tokenId), studentInfo)

        // Emit graduation event
        std.Emit(ufmt.Sprintf("student_graduated:tokenId=%s:graduatedAt=%s",
                string(tokenId),
                currentHeight,
        ))

        return nil
}

// UpdateStudentStatus updates a student's academic status
func (r *RAFStudentRegistry) UpdateStudentStatus(
        tokenId grc721.TokenID,
        newStatus string,
        reason string,
) error {
        if !r.IsAdmin(std.GetOrigCaller()) {
                return ErrUnauthorized
        }

        info, exists := r.students.Get(string(tokenId))
        if !exists {
                return ErrInvalidStudent
        }

        studentInfo := info.(StudentInfo)
        if studentInfo.GraduatedAt != nil {
                return ErrAlreadyGraduated
        }

        // Validate status
        validStatuses := map[string]bool{
                "Active":             true,
                "Academic Probation": true,
        }
        if !validStatuses[newStatus] {
                return errors.New("invalid status")
        }

        studentInfo.Status = newStatus
        studentInfo.ProbationReason = reason
        r.students.Set(string(tokenId), studentInfo)

        std.Emit(ufmt.Sprintf("student_status_updated:tokenId=%s:status=%s:reason=%s",
                string(tokenId),
                newStatus,
                reason,
        ))

        return nil
}

// TransferDepartment updates a student's department
func (r *RAFStudentRegistry) TransferDepartment(
        tokenId grc721.TokenID,
        newDepartment string,
) error {
        if !r.IsAdmin(std.GetOrigCaller()) {
                return ErrUnauthorized
        }

        info, exists := r.students.Get(string(tokenId))
        if !exists {
                return ErrInvalidStudent
        }

        studentInfo := info.(StudentInfo)
        if studentInfo.GraduatedAt != nil {
                return ErrAlreadyGraduated
        }

        studentInfo.Department = newDepartment
        r.students.Set(string(tokenId), studentInfo)

        std.Emit(ufmt.Sprintf("student_department_transferred:tokenId=%s:department=%s",
                string(tokenId),
                newDepartment,
        ))

        return nil
}
