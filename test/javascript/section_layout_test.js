'use strict';

function testSectionLayout(planSections) {
  const otherFieldsTitle = 'Autres champs';
  const cases = [
    {
      name: 'explicit empty right column keeps two columns and the left field order',
      sections: [{ title: '<b>Title</b>', left: [2, 1], right: [] }],
      fields: [{ id: '1' }, { id: 2 }],
      expected: [['<b>Title</b>', true, [2, 1], [], []]]
    },
    {
      name: 'full-width fields follow the left-then-right configured order',
      sections: [
        { title: 'Mixed', left: [3, 1], right: [4, 2] },
        { title: 'Wide only', left: [5] }
      ],
      fields: [
        { id: '1' }, { id: '2' }, { id: '4', fullWidth: true },
        { id: '3', fullWidth: true }, { id: '5', fullWidth: true }
      ],
      expected: [['Mixed', true, [1], [2], [3, 4]], ['Wide only', false, [], [], [5]]]
    },
    {
      name: 'unclassified fields keep native order and an odd count favors the left column',
      sections: [{ title: 'Configured', left: [1] }],
      fields: [
        { id: '1' }, { id: '5' }, { id: '6', fullWidth: true }, { id: '3' },
        { id: '4' }, { id: '7', fullWidth: true }
      ],
      expected: [['Configured', false, [1], [], []], [otherFieldsTitle, true, [5, 3], [4], [6, 7]]]
    },
    {
      name: 'sections with absent fields are skipped and a populated right column is kept',
      sections: [{ title: 'Missing', left: [9] }, { title: 'Right', left: [8], right: [1] }],
      fields: [{ id: '1' }],
      expected: [['Right', true, [], [1], []]]
    },
    {
      name: 'other fields can contain only full-width fields',
      sections: [{ title: 'Configured', left: [1] }],
      fields: [{ id: '1' }, { id: '2', fullWidth: true }],
      expected: [['Configured', false, [1], [], []], [otherFieldsTitle, true, [], [], [2]]]
    },
    {
      name: 'all available fields go to other fields when configured fields are absent',
      sections: [{ title: 'Missing', left: [9] }],
      fields: [{ id: '1' }],
      expected: [[otherFieldsTitle, true, [1], [], []]]
    },
    {
      name: 'no configured sections means no layout even when fields exist',
      sections: [],
      fields: [{ id: '1' }],
      expected: []
    },
    {
      name: 'no available fields means no empty section is created',
      sections: [{ title: 'Missing', left: [1] }],
      fields: [],
      expected: []
    }
  ];

  const ids = fields => fields.map(field => Number(field.id));
  for (const { name, sections, fields, expected } of cases) {
    const actual = planSections(sections, fields, otherFieldsTitle).map(section => [
      section.title, section.twoColumns, ids(section.left), ids(section.right), ids(section.fullWidth)
    ]);
    if (JSON.stringify(actual) !== JSON.stringify(expected)) {
      throw new Error(`${name}\nExpected: ${JSON.stringify(expected)}\nActual: ${JSON.stringify(actual)}`);
    }
  }
  return cases.length;
}

// Run with: node test/javascript/section_layout_test.js
if (typeof module !== 'undefined' && require.main === module) {
  const { readFileSync } = require('node:fs');
  const { resolve } = require('node:path');
  const filename = resolve(__dirname, '../../app/views/redmine_form_sections/_section_layout.js.erb');
  const source = readFileSync(filename, 'utf8');
  const planSections = new Function(`${source}\nreturn planSections;`)();
  console.log(`${testSectionLayout(planSections)} section layout tests passed`);
}
