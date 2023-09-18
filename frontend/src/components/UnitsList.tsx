import React from 'react'

interface Unit {
  key: string,
  value: {
    name: string,
    description: string,
    image_url: string,
  }
}

interface UnitsListProps {
  unitsList: Array<Unit>
}

const UnitRow = ({ unitData }: any) => (
  <div className="unit-row">
    <img width="200px" height="200px" src={unitData.image_url} alt="unit" />
    <p>{unitData.name}</p>
    <p>{unitData.description}</p>
    <p>Heath (❤️): {unitData.health}</p>
    <p>Attack (⚔️): {unitData.attack}</p>
  </div>
)

const UnitsList = ({ unitsList }: UnitsListProps) => (
  <div>
    <h3>All created units:</h3>
    <div className="units-list">
      {unitsList.length > 0 && unitsList.map((unitData) => <UnitRow key={unitData.key} unitData={unitData.value}/>)}
    </div>
  </div>
)

export default UnitsList