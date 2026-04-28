require('dotenv').config();
const mongoose = require('mongoose');
const Building = require('./models/Building');
const Cleaner = require('./models/Cleaner');

async function run() {
  await mongoose.connect(process.env.MONGO_URI);
  
  await Building.updateOne({ name: /Apex Towers/i }, { $set: { email: 'admin@apextowers.com' } });
  await Building.updateOne({ name: /Horizon Complex/i }, { $set: { email: 'admin@horizoncomplex.com' } });
  await Building.updateOne({ name: /Eco Lofts/i }, { $set: { email: 'admin@ecolofts.com' } });
  await Building.updateOne({ name: /^new$/i }, { $set: { email: 'admin@new.com' } });
  await Building.updateOne({ name: /Radhey Residency/i }, { $set: { email: 'admin@radheyresidency.com' } });

  await Cleaner.updateOne({ name: /Jaideep/i }, { $set: { email: 'jaideep@bmc.gov' } });
  await Cleaner.updateOne({ name: /samruddh/i }, { $set: { email: 'samruddh@bmc.gov' } });
  await Cleaner.updateOne({ name: /cleaner 1/i }, { $set: { email: 'cleaner1@bmc.gov' } });
  await Cleaner.updateOne({ name: /ameya/i }, { $set: { email: 'ameya@bmc.gov' } });
  await Cleaner.updateOne({ name: /harsh/i }, { $set: { email: 'harsh@bmc.gov' } });
  
  console.log('Database successfully seeded with emails.');
  process.exit(0);
}

run().catch(console.error);
