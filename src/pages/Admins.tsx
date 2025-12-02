import { useEffect, useState } from 'react'
import { useAuth } from '@/hooks/useAuth'
import { getAdmins, createAdmin, updateAdmin, deleteAdmin } from '@/lib/api/admins'
import { getDepartments } from '@/lib/api/departments'
import { Table } from '@/components/ui/Table'
import { Button } from '@/components/ui/Button'
import { Modal } from '@/components/ui/Modal'
import { Input } from '@/components/ui/Input'
import { FilterDropdown } from '@/components/ui/FilterDropdown'
import type { Admin, Department } from '@/types/database'

// Default admin username that is protected
const DEFAULT_ADMIN_USERNAME = 'admin'

export function Admins() {
  const { user } = useAuth()
  const [admins, setAdmins] = useState<Admin[]>([])
  const [departments, setDepartments] = useState<Department[]>([])
  const [loading, setLoading] = useState(true)
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [editingAdmin, setEditingAdmin] = useState<Admin | null>(null)
  const [formData, setFormData] = useState({
    name: '',
    username: '',
    password: '',
    department_id: '',
    is_active: true,
  })

  useEffect(() => {
    fetchAdmins()
    fetchDepartments()
  }, [])

  const fetchAdmins = async () => {
    try {
      const data = await getAdmins()
      // Filter out: default admin AND current logged-in user
      const currentUserId = user?.id ? parseInt(user.id) : null
      const filteredAdmins = data.filter((admin) =>
        admin.username !== DEFAULT_ADMIN_USERNAME &&
        admin.id !== currentUserId
      )
      setAdmins(filteredAdmins)
    } catch (error) {
      console.error('Failed to fetch admins:', error)
    } finally {
      setLoading(false)
    }
  }

  const fetchDepartments = async () => {
    try {
      const data = await getDepartments()
      setDepartments(data)
    } catch (error) {
      console.error('Failed to fetch departments:', error)
    }
  }

  const handleCreate = () => {
    setEditingAdmin(null)
    setFormData({
      name: '',
      username: '',
      password: '',
      department_id: '',
      is_active: true,
    })
    setIsModalOpen(true)
  }

  const handleEdit = (admin: Admin) => {
    setEditingAdmin(admin)
    setFormData({
      name: admin.name,
      username: admin.username,
      password: '',
      department_id: admin.department_id?.toString() || '',
      is_active: admin.is_active,
    })
    setIsModalOpen(true)
  }

  const handleDelete = async (id: number) => {
    if (!confirm('Are you sure you want to delete this admin?')) return

    try {
      await deleteAdmin(id)
      fetchAdmins()
    } catch (error) {
      console.error('Failed to delete admin:', error)
      alert('Failed to delete admin')
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    try {
      const adminData = {
        name: formData.name,
        username: formData.username,
        password: formData.password,
        department_id: formData.department_id ? parseInt(formData.department_id) : null,
        is_active: formData.is_active,
      }

      if (editingAdmin) {
        await updateAdmin(editingAdmin.id, adminData)
      } else {
        await createAdmin(adminData)
      }

      setIsModalOpen(false)
      fetchAdmins()
    } catch (error: any) {
      console.error('Failed to save admin:', error)
      alert(error.message || 'Failed to save admin')
    }
  }

  const columns = [
    {
      key: 'name',
      header: 'Name',
    },
    {
      key: 'username',
      header: 'Username',
    },
    {
      key: 'department_id',
      header: 'Department',
      render: (admin: Admin) => {
        const dept = departments.find((d) => d.id === admin.department_id)
        return dept?.name || 'N/A'
      },
    },
    {
      key: 'is_active',
      header: 'Status',
      render: (admin: Admin) => (
        <span className={`status-badge ${admin.is_active ? 'status-active' : 'status-inactive'}`}>
          {admin.is_active ? 'Active' : 'Inactive'}
        </span>
      ),
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (admin: Admin) => (
        <div className="action-buttons">
          <Button size="sm" variant="secondary" onClick={() => handleEdit(admin)}>
            Edit
          </Button>
          <Button size="sm" variant="danger" onClick={() => handleDelete(admin.id)}>
            Delete
          </Button>
        </div>
      ),
    },
  ]

  if (loading) {
    return (
      <div className="page-wrapper">
        <div className="loading-wrapper">
          <div className="loading-content">
            <div className="loading-spinner"></div>
            <p className="loading-message">Loading admins...</p>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="page-wrapper">
      <div className="page-header-section">
        <div className="page-info">
          <h1 className="page-heading">Admins</h1>
          <p className="page-subheading">Manage admin accounts</p>
        </div>
        <button onClick={handleCreate} className="primary-action-btn">
          + Add Admin
        </button>
      </div>

      <div className="content-card">
        <Table columns={columns} data={admins} />
      </div>

      <Modal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        title={editingAdmin ? 'Edit Admin' : 'Create Admin'}
        footer={
          <>
            <Button variant="secondary" onClick={() => setIsModalOpen(false)}>
              Cancel
            </Button>
            <Button onClick={handleSubmit}>Save</Button>
          </>
        }
      >
        <form onSubmit={handleSubmit} className="modal-form">
          <Input
            label="Name"
            value={formData.name}
            onChange={(e) => setFormData({ ...formData, name: e.target.value })}
            required
          />
          <Input
            label="Username"
            value={formData.username}
            onChange={(e) => setFormData({ ...formData, username: e.target.value })}
            required
          />
          <Input
            label={editingAdmin ? 'New Password (leave empty to keep current)' : 'Password'}
            type="password"
            value={formData.password}
            onChange={(e) => setFormData({ ...formData, password: e.target.value })}
            required={!editingAdmin}
          />
          <FilterDropdown
            label="Department"
            value={formData.department_id}
            onChange={(value) => setFormData({ ...formData, department_id: value })}
            placeholder="None (Super Admin)"
            options={[
              { value: '', label: 'None (Super Admin)' },
              ...departments.map((dept) => ({
                value: dept.id.toString(),
                label: dept.name,
              })),
            ]}
          />
          <div className="form-checkbox-group">
            <input
              type="checkbox"
              id="is_active"
              checked={formData.is_active}
              onChange={(e) => setFormData({ ...formData, is_active: e.target.checked })}
              className="form-checkbox"
            />
            <label htmlFor="is_active" className="form-checkbox-label">
              Active
            </label>
          </div>
        </form>
      </Modal>
    </div>
  )
}

