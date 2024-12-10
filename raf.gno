package raf

import (
        "std"
        "strings"

        "gno.land/p/demo/grc/grc721"
        "gno.land/p/demo/ufmt"
        "gno.land/p/moul/md"
)

// Global state variable for the registry
var (
        registry *RAFStudentRegistry
)

// init initializes the realm with the first admin
func init() {
        if registry == nil {
                // Initialize with the first admin (you would set this to your address)
                firstAdmin := std.Address("g1ej0qca5ptsw9kfr64ey8jvfy9eacga6mpj2z0y") // example address
                registry = NewRAFStudentRegistry(firstAdmin)
        }
}

// Public functions to interact with the registry

// IssueNewStudent creates a new student NFT (only callable by admin)
func IssueNewStudent(
        studentAddr std.Address,
        fullName string,
        dateOfBirth string,
        email string,
        studentID string,
        department string,
        year uint8,
        enrolledAt string,
) error {
        info := StudentInfo{
                FullName:    fullName,
                DateOfBirth: dateOfBirth,
                Email:       email,
                StudentID:   studentID,
                EnrolledAt:  enrolledAt,
                Department:  department,
                Year:        year,
        }

        _, err := registry.IssueStudentNFT(studentAddr, info)
        return err
}

// AddNewAdmin adds a new admin (only callable by existing admin)
func AddNewAdmin(newAdmin std.Address) error {
        return registry.AddAdmin(newAdmin)
}

// RemoveExistingAdmin removes an admin (only callable by existing admin)
func RemoveExistingAdmin(admin std.Address) error {
        return registry.RemoveAdmin(admin)
}

// UpdateStudentYear updates a student's year (only callable by admin)
func UpdateStudentYear(studentID string, newYear uint8) error {
        return registry.UpdateStudentYear(grc721.TokenID(studentID), newYear)
}

// GetStudentInfo retrieves student information
func GetStudentInfo(studentID string) (*StudentInfo, error) {
        info, exists := registry.students.Get(studentID)
        if !exists {
                return nil, ErrInvalidStudent
        }
        studentInfo := info.(StudentInfo)
        return &studentInfo, nil
}

// IsStudentEnrolled checks if a student is currently enrolled
func IsStudentEnrolled(studentAddr std.Address) bool {
        balance, err := registry.BalanceOf(studentAddr)
        if err != nil {
                return false
        }
        return balance > 0
}

// Render displays information about the registry and recent students
func Render(path string) string {
        if registry == nil {
                return "Registry not initialized"
        }

        var output string
        output += md.H1("RAF Student Registry")

        // Get all students and sort by enrollment date (most recent first)
        var students []struct {
                ID   string
                Info StudentInfo
        }

        registry.students.Iterate("", "", func(key string, value interface{}) bool {
                info := value.(StudentInfo)
                students = append(students, struct {
                        ID   string
                        Info StudentInfo
                }{
                        ID:   key,
                        Info: info,
                })
                return false
        })

        // Sort students by enrollment date (most recent first)
        for i := 0; i < len(students)-1; i++ {
                for j := 0; j < len(students)-i-1; j++ {
                        if students[j].Info.EnrolledAt < students[j+1].Info.EnrolledAt {
                                students[j], students[j+1] = students[j+1], students[j]
                        }
                }
        }

        // Display total number of students
        output += md.Paragraph(ufmt.Sprintf("Total Students: %s", md.Bold(ufmt.Sprintf("%d", len(students)))))        

        // Display table header
        output += md.H2("Recent Students")

        // Create table header
        tableRows := []string{
                "Student ID ________| Full Name______________ | Department _______| Year___________   | Enrolled At", 
                "-------------------|-------------------------|-------------------|-------------------|-------------",
        }

        // Add up to 5 most recent students
        count := 0
        for _, student := range students {
                if count >= 5 {
                        break
                }
                tableRows = append(tableRows, ufmt.Sprintf("%s | %s | %s | %d | %s",
                        student.Info.StudentID,
                        student.Info.FullName,
                        student.Info.Department,
                        student.Info.Year,
                        student.Info.EnrolledAt,
                ))
                count++
        }

        // If no students found
        if count == 0 {
                output += md.Italic("No students enrolled yet.")
        } else {
                // Create table by joining rows with newlines
                table := strings.Join(tableRows, "\n")
                output += table + "\n"
        }

        return output
}

// GraduateStudent marks a student as graduated (only callable by admin)
func GraduateStudent(studentID string) error {
        info, err := GetStudentInfo(studentID)
        if err != nil {
                return err
        }

        // Verify student is in final year (assuming 4-year program)
        if info.Year != 4 {
                return std.Errorf("student must be in final year to graduate")
        }

        // Transfer the NFT back to the registry (representing graduation)
        studentAddr, err := registry.OwnerOf(grc721.TokenID(studentID))
        if err != nil {
                return err
        }

        // Update student status to graduated
        info.Status = "Graduated"
        info.GraduationDate = std.GetHeight().String() // Using block height as graduation date
        registry.students.Set(studentID, *info)

        // Transfer NFT back to registry
        return registry.TransferFrom(studentAddr, registry.adminAddress, grc721.TokenID(studentID))
}

// TransferStudent handles student transfer between departments (only callable by admin)
func TransferStudent(studentID string, newDepartment string) error {
        info, err := GetStudentInfo(studentID)
        if err != nil {
                return err
        }

        if !registry.IsAdmin(std.GetOrigCaller()) {
                return ErrNotAdmin
        }

        info.Department = newDepartment
        registry.students.Set(studentID, *info)
        return nil
}

// PutOnAcademicProbation marks a student as being on academic probation
func PutOnAcademicProbation(studentID string, reason string) error {
        if !registry.IsAdmin(std.GetOrigCaller()) {
                return ErrNotAdmin
        }

        info, err := GetStudentInfo(studentID)
        if err != nil {
                return err
        }

        info.Status = "Academic Probation"
        info.ProbationReason = reason
        registry.students.Set(studentID, *info)
        return nil
}

// RemoveFromAcademicProbation removes a student from academic probation
func RemoveFromAcademicProbation(studentID string) error {
        if !registry.IsAdmin(std.GetOrigCaller()) {
                return ErrNotAdmin
        }

        info, err := GetStudentInfo(studentID)
        if err != nil {
                return err
        }

        info.Status = "Active"
        info.ProbationReason = ""
        registry.students.Set(studentID, *info)
        return nil
}
