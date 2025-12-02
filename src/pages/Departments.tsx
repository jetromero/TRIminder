import { useEffect, useState } from 'react'
import { getDepartments, createDepartment, updateDepartment, deleteDepartment } from '@/lib/api/departments'
import { Table } from '@/components/ui/Table'
import { Button } from '@/components/ui/Button'
import { Modal } from '@/components/ui/Modal'
import { Input } from '@/components/ui/Input'
import type { Department } from '@/types/database'

export function Departments() {
  const [departments, setDepartments] = useState<Department[]>([])
  const [loading, setLoading] = useState(true)
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [editingDepartment, setEditingDepartment] = useState<Department | null>(null)
  const [formData, setFormData] = useState({ name: '' })

  useEffect(() => {
    fetchDepartments()
  }, [])

  const fetchDepartments = async () => {
    try {
      const data = await getDepartments()
      setDepartments(data)
    } catch (error) {
      console.error('Failed to fetch departments:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleCreate = () => {
    setEditingDepartment(null)
    setFormData({ name: '' })
    setIsModalOpen(true)
  }

  const handleEdit = (department: Department) => {
    setEditingDepartment(department)
    setFormData({ name: department.name })
    setIsModalOpen(true)
  }

  const handleDelete = async (id: number) => {
    if (!confirm('Are you sure you want to delete this department?')) return

    try {
      await deleteDepartment(id)
      fetchDepartments()
    } catch (error) {
      console.error('Failed to delete department:', error)
      alert('Failed to delete department')
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    try {
      if (editingDepartment) {
        await updateDepartment(editingDepartment.id, formData)
      } else {
        await createDepartment(formData)
      }

      setIsModalOpen(false)
      fetchDepartments()
    } catch (error: any) {
      console.error('Failed to save department:', error)
      alert(error.message || 'Failed to save department')
    }
  }

  const columns = [
    {
      key: 'name',
      header: 'Name',
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (department: Department) => (
        <div className="flex gap-2">
          <Button size="sm" variant="secondary" onClick={() => handleEdit(department)}>
            Edit
          </Button>
          <Button size="sm" variant="danger" onClick={() => handleDelete(department.id)}>
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
            <p className="loading-message">Loading departments...</p>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="page-wrapper">
      <div className="page-header-section">
        <div className="page-info">
          <h1 className="page-heading">Departments</h1>
          <p className="page-subheading">Manage departments</p>
        </div>
        <button onClick={handleCreate} className="primary-action-btn">
          + Add Department
        </button>
      </div>

      <div className="content-card">
        <Table columns={columns} data={departments} />
      </div>

      <Modal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        title={editingDepartment ? 'Edit Department' : 'Create Department'}
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
        </form>
      </Modal>
    </div>
  )
}

