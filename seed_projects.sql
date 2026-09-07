-- ============================================================================
-- AssembleAI: Seed Initial 3 Projects (Electronics & Furniture)
-- ============================================================================
-- Fully idempotent: uses ON CONFLICT (id) DO UPDATE.
-- Can be executed multiple times safely in the Supabase SQL Editor.
-- Covers diverse physical assembly domains:
--   1. LED Circuit (Electronics / Breadboard)
--   2. Temperature Sensor (Electronics / Analog Sensor)
--   3. Modular Bookshelf (Furniture / Mechanical Fasteners)
-- ============================================================================

-- Ensure helper columns exist
alter table public.projects add column if not exists category text default 'General Assembly';
alter table public.assembly_steps add column if not exists expected_duration_minutes integer default 2;
alter table public.components add column if not exists part_id text;
alter table public.components add column if not exists is_required boolean default true;
alter table public.components add column if not exists quantity integer default 1;

-- ============================================================================
-- PROJECT 1: LED Circuit (Electronics)
-- ============================================================================
insert into public.projects (
    id,
    owner_id,
    title,
    description,
    difficulty,
    estimated_minutes,
    thumbnail_path,
    category,
    is_public,
    sync_state
) values (
    '11111111-1111-1111-1111-111111111111',
    null,
    'LED Circuit',
    'Build a simple LED circuit using a breadboard, resistor, LED, and jumper wires. Learn basic pin header connections and current limiting.',
    'Beginner',
    15,
    'bolt.batteryblock.fill',
    'Electronics',
    true,
    'synced'
)
on conflict (id) do update set
    title = excluded.title,
    description = excluded.description,
    difficulty = excluded.difficulty,
    estimated_minutes = excluded.estimated_minutes,
    thumbnail_path = excluded.thumbnail_path,
    category = excluded.category,
    is_public = excluded.is_public,
    sync_state = excluded.sync_state,
    updated_at = now();

-- Components for Project 1
insert into public.components (id, project_id, name, type, description, metadata, part_id, is_required, quantity)
values
    ('C0000001-0001-0001-0001-000000000001', '11111111-1111-1111-1111-111111111111', 'Breadboard', 'board', '830 tie-point solderless board', '{"component_type":"board"}', 'part_breadboard', true, 1),
    ('C0000001-0001-0001-0001-000000000002', '11111111-1111-1111-1111-111111111111', 'Red LED', 'led', '5mm diffuse red LED', '{"component_type":"led","physical_attributes":{"polarity_sensitive":true,"orientation_marker":"Long lead is anode (positive). Flat edge on housing marks cathode (negative).","package_type":"5mm","nominal_value":"5mm red"}}', 'part_led_red', true, 1),
    ('C0000001-0001-0001-0001-000000000003', '11111111-1111-1111-1111-111111111111', '220Ω Resistor', 'resistor', '1/4W carbon film resistor', '{"component_type":"resistor","physical_attributes":{"color_bands":["red","red","brown","gold"],"polarity_sensitive":false,"package_type":"axial","nominal_value":"220Ω"}}', 'part_res_220', true, 1),
    ('C0000001-0001-0001-0001-000000000004', '11111111-1111-1111-1111-111111111111', 'Jumper Wires', 'jumper_wire', 'Male-to-male wire set', '{"component_type":"jumper_wire"}', 'part_jumper', true, 3),
    ('C0000001-0001-0001-0001-000000000005', '11111111-1111-1111-1111-111111111111', '5V Power Source', 'connector', 'USB breadboard power supply', '{"component_type":"connector"}', 'part_psu_5v', false, 1)
on conflict (id) do update set
    name = excluded.name,
    type = excluded.type,
    description = excluded.description,
    metadata = excluded.metadata,
    part_id = excluded.part_id,
    is_required = excluded.is_required,
    quantity = excluded.quantity;

-- Steps for Project 1
insert into public.assembly_steps (id, project_id, step_order, title, instruction, expected_duration_minutes, expected_state)
values
    ('A0000001-0001-0001-0001-000000000001', '11111111-1111-1111-1111-111111111111', 1, 'Insert 220Ω Resistor', 'Place the 220Ω resistor bridging Row 10 to Row 15 across the center divider of the breadboard.', 2, '{"tolerance_mm":2.5,"orientation_constraints":[],"expected_connections":[],"required_component_ids":["part_res_220"],"spatial_placements":[],"pin_placements":[{"part_id":"part_res_220","tolerance_mm":2.5,"from_pin":{"row":"10","column":"E"},"to_pin":{"row":"15","column":"F"}}]}'),
    ('A0000001-0001-0001-0001-000000000002', '11111111-1111-1111-1111-111111111111', 2, 'Insert 100µF Capacitor', 'Insert the 100µF electrolytic capacitor into the C2 header slot, observing polarity. The white stripe (negative) faces the GND rail.', 2, '{"tolerance_mm":2.5,"orientation_constraints":[{"part_id":"part_cap_100u","marker_type":"polarity_stripe","rule":"White stripe (cathode) faces GND rail"}],"expected_connections":[],"required_component_ids":["part_cap_100u"],"spatial_placements":[],"pin_placements":[]}'),
    ('A0000001-0001-0001-0001-000000000003', '11111111-1111-1111-1111-111111111111', 3, 'Connect LED Anode to Node 12A', 'Align the long lead (anode) of the red LED with pin 12A on the breadboard.', 2, '{"tolerance_mm":2.5,"orientation_constraints":[{"part_id":"part_led_red","marker_type":"anode_cathode","rule":"Long lead (anode) inserted into Row 12A. Flat edge on housing faces away from resistor."}],"expected_connections":[{"connection_type":"wire","from_node":"led_anode","to_node":"12A"}],"required_component_ids":["part_led_red"],"spatial_placements":[],"pin_placements":[{"part_id":"part_led_red","tolerance_mm":2.5,"from_pin":{"row":"12","column":"A"},"to_pin":{"row":"12","column":"B"}}]}'),
    ('A0000001-0001-0001-0001-000000000004', '11111111-1111-1111-1111-111111111111', 4, 'Place Current Limiting Resistor', 'Bridge the current limiting resistor from pin 12B to the ground rail.', 1, '{"tolerance_mm":2.5,"orientation_constraints":[],"expected_connections":[{"connection_type":"wire","from_node":"12B","to_node":"GND_rail"}],"required_component_ids":["part_res_220"],"spatial_placements":[],"pin_placements":[]}'),
    ('A0000001-0001-0001-0001-000000000005', '11111111-1111-1111-1111-111111111111', 5, 'Insert Ground Jumper Wire', 'Connect a black jumper wire from the breadboard GND rail to the power supply ground terminal.', 1, '{"tolerance_mm":2.5,"orientation_constraints":[],"expected_connections":[{"connection_type":"wire","from_node":"GND_rail","to_node":"PSU_GND"}],"required_component_ids":["part_jumper"],"spatial_placements":[],"pin_placements":[]}'),
    ('A0000001-0001-0001-0001-000000000006', '11111111-1111-1111-1111-111111111111', 6, 'Connect VCC Jumper Wire', 'Connect a red jumper wire from the VCC positive bus line to the power supply 5V terminal.', 1, '{"tolerance_mm":2.5,"orientation_constraints":[],"expected_connections":[{"connection_type":"wire","from_node":"VCC_rail","to_node":"PSU_5V"}],"required_component_ids":["part_jumper"],"spatial_placements":[],"pin_placements":[]}'),
    ('A0000001-0001-0001-0001-000000000007', '11111111-1111-1111-1111-111111111111', 7, 'Verify Voltage Drop Across Resistor', 'Use a multimeter to measure the voltage drop across the 220Ω resistor. Expected reading: approximately 2.8V.', 3, '{}'),
    ('A0000001-0001-0001-0001-000000000008', '11111111-1111-1111-1111-111111111111', 8, 'Power Circuit and Observe', 'Switch the power supply ON and confirm the LED illuminates bright red. If not, check all connections and polarity.', 1, '{}')
on conflict (id) do update set
    project_id = excluded.project_id,
    step_order = excluded.step_order,
    title = excluded.title,
    instruction = excluded.instruction,
    expected_duration_minutes = excluded.expected_duration_minutes,
    expected_state = excluded.expected_state,
    updated_at = now();

-- ============================================================================
-- PROJECT 2: Temperature Sensor (Electronics)
-- ============================================================================
insert into public.projects (
    id,
    owner_id,
    title,
    description,
    difficulty,
    estimated_minutes,
    thumbnail_path,
    category,
    is_public,
    sync_state
) values (
    '22222222-2222-2222-2222-222222222222',
    null,
    'Temperature Sensor',
    'Assemble a high-precision NTC thermistor circuit with voltage divider output feeding into an analog microcontroller pin.',
    'Beginner',
    25,
    'thermometer.medium',
    'Electronics',
    true,
    'synced'
)
on conflict (id) do update set
    title = excluded.title,
    description = excluded.description,
    difficulty = excluded.difficulty,
    estimated_minutes = excluded.estimated_minutes,
    thumbnail_path = excluded.thumbnail_path,
    category = excluded.category,
    is_public = excluded.is_public,
    sync_state = excluded.sync_state,
    updated_at = now();

-- Components for Project 2
insert into public.components (id, project_id, name, type, description, metadata, part_id, is_required, quantity)
values
    ('C0000002-0001-0001-0001-000000000001', '22222222-2222-2222-2222-222222222222', 'NTC Thermistor 10K', 'sensor', '10K ohm @ 25°C thermal sensor', '{"component_type":"sensor","physical_attributes":{"polarity_sensitive":false,"nominal_value":"10KΩ NTC"}}', 'part_thermistor_10k', true, 1),
    ('C0000002-0001-0001-0001-000000000002', '22222222-2222-2222-2222-222222222222', '10K Precision Resistor', 'resistor', '1% metal film resistor', '{"component_type":"resistor","physical_attributes":{"color_bands":["brown","black","orange","brown"],"polarity_sensitive":false,"nominal_value":"10KΩ"}}', 'part_res_10k', true, 1),
    ('C0000002-0001-0001-0001-000000000003', '22222222-2222-2222-2222-222222222222', 'Breadboard', 'board', 'Half-size breadboard', '{"component_type":"board"}', 'part_breadboard_half', true, 1),
    ('C0000002-0001-0001-0001-000000000004', '22222222-2222-2222-2222-222222222222', 'Jumper Wires', 'jumper_wire', 'Male-to-male wire set', '{"component_type":"jumper_wire"}', 'part_jumper', true, 3)
on conflict (id) do update set
    name = excluded.name,
    type = excluded.type,
    description = excluded.description,
    metadata = excluded.metadata,
    part_id = excluded.part_id,
    is_required = excluded.is_required,
    quantity = excluded.quantity;

-- Steps for Project 2
insert into public.assembly_steps (id, project_id, step_order, title, instruction, expected_duration_minutes, expected_state)
values
    ('A0000002-0001-0001-0001-000000000001', '22222222-2222-2222-2222-222222222222', 1, 'Insert NTC Thermistor', 'Place thermistor leads across pin A5 and pin A10 on the breadboard.', 3, '{"tolerance_mm":2.5,"orientation_constraints":[],"expected_connections":[],"required_component_ids":["part_thermistor_10k"],"spatial_placements":[],"pin_placements":[{"part_id":"part_thermistor_10k","tolerance_mm":2.5,"from_pin":{"row":"5","column":"A"},"to_pin":{"row":"10","column":"A"}}]}'),
    ('A0000002-0001-0001-0001-000000000002', '22222222-2222-2222-2222-222222222222', 2, 'Insert Voltage Divider Resistor', 'Place the 10K precision resistor from pin B10 to pin B15, forming the lower leg of the voltage divider.', 3, '{"tolerance_mm":2.5,"orientation_constraints":[],"expected_connections":[],"required_component_ids":["part_res_10k"],"spatial_placements":[],"pin_placements":[{"part_id":"part_res_10k","tolerance_mm":2.5,"from_pin":{"row":"10","column":"B"},"to_pin":{"row":"15","column":"B"}}]}'),
    ('A0000002-0001-0001-0001-000000000003', '22222222-2222-2222-2222-222222222222', 3, 'Connect VCC to Thermistor', 'Connect a jumper wire from the 5V power rail to Row 5 to supply voltage to the thermistor.', 2, '{"tolerance_mm":2.5,"orientation_constraints":[],"expected_connections":[{"connection_type":"wire","from_node":"VCC_5V","to_node":"Row5"}],"required_component_ids":["part_jumper"],"spatial_placements":[],"pin_placements":[]}'),
    ('A0000002-0001-0001-0001-000000000004', '22222222-2222-2222-2222-222222222222', 4, 'Connect Analog Output and Ground', 'Connect a jumper from Row 10 (voltage divider midpoint) to the analog input pin. Connect Row 15 to GND rail.', 3, '{"tolerance_mm":2.5,"orientation_constraints":[],"expected_connections":[{"connection_type":"wire","from_node":"Row10","to_node":"ADC_A0"},{"connection_type":"wire","from_node":"Row15","to_node":"GND_rail"}],"required_component_ids":["part_jumper"],"spatial_placements":[],"pin_placements":[]}')
on conflict (id) do update set
    project_id = excluded.project_id,
    step_order = excluded.step_order,
    title = excluded.title,
    instruction = excluded.instruction,
    expected_duration_minutes = excluded.expected_duration_minutes,
    expected_state = excluded.expected_state,
    updated_at = now();

-- ============================================================================
-- PROJECT 3: Modular Bookshelf (Furniture / Mechanical Fasteners)
-- ============================================================================
insert into public.projects (
    id,
    owner_id,
    title,
    description,
    difficulty,
    estimated_minutes,
    thumbnail_path,
    category,
    is_public,
    sync_state
) values (
    '66666666-6666-6666-6666-666666666666',
    null,
    'Modular Bookshelf',
    'Assemble a 3-tier modular bookshelf from flat-pack components using cam lock fasteners, wooden dowels, and hex bolts. No power tools required.',
    'Beginner',
    35,
    'books.vertical.fill',
    'Furniture',
    true,
    'synced'
)
on conflict (id) do update set
    title = excluded.title,
    description = excluded.description,
    difficulty = excluded.difficulty,
    estimated_minutes = excluded.estimated_minutes,
    thumbnail_path = excluded.thumbnail_path,
    category = excluded.category,
    is_public = excluded.is_public,
    sync_state = excluded.sync_state,
    updated_at = now();

-- Components for Project 3
insert into public.components (id, project_id, name, type, description, metadata, part_id, is_required, quantity)
values
    ('C0000006-0001-0001-0001-000000000001', '66666666-6666-6666-6666-666666666666', 'Side Panel', 'panel', 'Melamine-coated particle board, 800mm x 300mm', '{"component_type":"panel"}', 'part_side_panel', true, 2),
    ('C0000006-0001-0001-0001-000000000002', '66666666-6666-6666-6666-666666666666', 'Shelf Board', 'shelf', 'Melamine-coated particle board, 600mm x 280mm', '{"component_type":"shelf"}', 'part_shelf', true, 3),
    ('C0000006-0001-0001-0001-000000000003', '66666666-6666-6666-6666-666666666666', 'Wooden Dowels', 'dowel', '8mm x 30mm beech dowel pins', '{"component_type":"dowel"}', 'part_dowel_8mm', true, 12),
    ('C0000006-0001-0001-0001-000000000004', '66666666-6666-6666-6666-666666666666', 'Cam Lock Bolts', 'cam_lock', 'M6 x 34mm zinc-plated cam bolt', '{"component_type":"cam_lock"}', 'part_cam_bolt', true, 6),
    ('C0000006-0001-0001-0001-000000000005', '66666666-6666-6666-6666-666666666666', 'Cam Lock Discs', 'cam_lock', '15mm zinc alloy cam disc', '{"component_type":"cam_lock"}', 'part_cam_disc', true, 6),
    ('C0000006-0001-0001-0001-000000000006', '66666666-6666-6666-6666-666666666666', 'Back Panel', 'panel', '3mm HDF backing board, 620mm x 780mm', '{"component_type":"panel"}', 'part_back_panel', true, 1),
    ('C0000006-0001-0001-0001-000000000007', '66666666-6666-6666-6666-666666666666', 'Nails', 'screw', '15mm panel pins for back panel', '{"component_type":"screw"}', 'part_nail_15mm', true, 8)
on conflict (id) do update set
    name = excluded.name,
    type = excluded.type,
    description = excluded.description,
    metadata = excluded.metadata,
    part_id = excluded.part_id,
    is_required = excluded.is_required,
    quantity = excluded.quantity;

-- Steps for Project 3
insert into public.assembly_steps (id, project_id, step_order, title, instruction, expected_duration_minutes, expected_state)
values
    ('A0000006-0001-0001-0001-000000000001', '66666666-6666-6666-6666-666666666666', 1, 'Insert Dowels into Side Panels', 'Press 6 wooden dowels into the pre-drilled holes on the inner face of each side panel. Each side panel has 6 holes arranged in 3 pairs.', 5, '{"tolerance_mm":1.0,"orientation_constraints":[],"expected_connections":[],"required_component_ids":["part_dowel_8mm","part_side_panel"],"spatial_placements":[{"location_description":"Inner face of left side panel, 3 pairs of pre-drilled holes at shelf height positions","orientation":"Flush with panel surface, seated fully in hole","part_id":"part_dowel_8mm","quantity":6},{"location_description":"Inner face of right side panel, mirroring left panel hole positions","orientation":"Flush with panel surface, seated fully in hole","part_id":"part_dowel_8mm","quantity":6}],"pin_placements":[]}'),
    ('A0000006-0001-0001-0001-000000000002', '66666666-6666-6666-6666-666666666666', 2, 'Thread Cam Lock Bolts into Shelves', 'Screw a cam lock bolt into each pre-drilled hole on the ends of all 3 shelf boards. Each shelf end has 1 bolt hole.', 5, '{"tolerance_mm":1.0,"orientation_constraints":[{"marker_type":"label_direction","part_id":"part_cam_bolt","rule":"Bolt threads must protrude from the shelf end face, not the shelf surface"}],"expected_connections":[],"required_component_ids":["part_cam_bolt","part_shelf"],"spatial_placements":[{"location_description":"Pre-drilled hole on each end of shelf board","orientation":"Bolt head flush with shelf edge, threads protruding from shelf end","part_id":"part_cam_bolt","quantity":2}],"pin_placements":[]}'),
    ('A0000006-0001-0001-0001-000000000003', '66666666-6666-6666-6666-666666666666', 3, 'Attach Bottom Shelf to Left Side Panel', 'Align the bottom shelf dowels with the lowest pair of holes on the left side panel. Insert the cam bolt into the cam disc hole and turn the disc clockwise to lock.', 5, '{"tolerance_mm":2.0,"orientation_constraints":[{"marker_type":"label_direction","part_id":"part_cam_disc","rule":"Arrow on cam disc points toward the cam bolt before turning. Turn clockwise 90 degrees to lock."}],"expected_connections":[{"connection_type":"cam_lock","from_node":"shelf_cam_bolt_left","to_node":"panel_cam_disc_bottom"}],"required_component_ids":["part_shelf","part_side_panel","part_cam_disc"],"spatial_placements":[{"location_description":"Bottom position on left side panel, shelf perpendicular to panel","orientation":"Shelf surface facing up, cam bolt aligned with cam disc hole","part_id":"part_shelf","quantity":1}],"pin_placements":[]}'),
    ('A0000006-0001-0001-0001-000000000004', '66666666-6666-6666-6666-666666666666', 4, 'Attach Middle and Top Shelves', 'Repeat the shelf attachment process for the middle and top shelf positions on the left side panel.', 8, '{"tolerance_mm":2.0,"orientation_constraints":[],"expected_connections":[],"required_component_ids":["part_shelf","part_cam_disc"],"spatial_placements":[{"location_description":"Middle and top positions on left side panel","orientation":"Shelf surfaces facing up, parallel and evenly spaced","part_id":"part_shelf","quantity":2}],"pin_placements":[]}'),
    ('A0000006-0001-0001-0001-000000000005', '66666666-6666-6666-6666-666666666666', 5, 'Attach Right Side Panel', 'Align the right side panel dowel holes and cam disc holes with the protruding dowels and cam bolts on the right ends of all 3 shelves. Press firmly and lock all 3 cam discs.', 8, '{"tolerance_mm":2.0,"orientation_constraints":[],"expected_connections":[],"required_component_ids":["part_side_panel","part_cam_disc"],"spatial_placements":[{"location_description":"Right side, flush with all 3 shelf ends","orientation":"Inner face with cam disc holes facing shelves, panel vertical","part_id":"part_side_panel","quantity":1}],"pin_placements":[]}'),
    ('A0000006-0001-0001-0001-000000000006', '66666666-6666-6666-6666-666666666666', 6, 'Attach Back Panel', 'Lay the assembled bookshelf face down. Place the HDF back panel over the rear opening and secure with 8 panel pins along the edges.', 5, '{"tolerance_mm":5.0,"orientation_constraints":[{"marker_type":"label_direction","part_id":"part_back_panel","rule":"Smooth side faces outward. Rough side faces the shelves."}],"expected_connections":[],"required_component_ids":["part_back_panel","part_nail_15mm"],"spatial_placements":[{"location_description":"Rear face of assembled bookshelf, covering full opening","orientation":"Smooth finished side facing outward (away from shelves)","part_id":"part_back_panel","quantity":1},{"location_description":"Evenly spaced along all four edges of back panel into side panels and shelves","orientation":"Perpendicular into frame","part_id":"part_nail_15mm","quantity":8}],"pin_placements":[]}')
on conflict (id) do update set
    project_id = excluded.project_id,
    step_order = excluded.step_order,
    title = excluded.title,
    instruction = excluded.instruction,
    expected_duration_minutes = excluded.expected_duration_minutes,
    expected_state = excluded.expected_state,
    updated_at = now();
