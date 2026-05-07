# CUPDataModel

Offline data model libraries for reading CUPDAQ raw data. Provides two independent modules:

- **RawObjs** — ROOT-based in-memory objects for FADC/SADC raw events
- **HDF5Utils** — HDF5 file I/O for event- and hit-based data

---

## Dependencies

| Library | Version | Required by |
|---------|---------|-------------|
| ROOT    | ≥ 6.20  | RawObjs, HDF5Utils |
| HDF5    | ≥ 1.10  | HDF5Utils (optional) |
| CMake   | ≥ 3.16  | build |

---

## Build

```bash
cmake -S . -B build \
      -DCMAKE_INSTALL_PREFIX=install \
      -DROOT_DIR=/path/to/root/cmake

cmake --build build -j$(nproc)
cmake --install build
```

To disable HDF5Utils:

```bash
cmake -S . -B build -DCUPDM_ENABLE_HDF5=OFF ...
```

After installing, source the environment script:

```bash
source install/setup_cupdm.sh
```

---

## RawObjs

ROOT dictionary library for in-memory representation of raw detector data. Intended for use with ROOT trees.

### Class hierarchy

```
AbsChannel
├── FChannel      FADC channel — waveform (up to 16384 samples)
└── AChannel      SADC channel — ADC sum + timestamp

FChannelData      TClonesArray container for FChannel
AChannelData      TClonesArray container for AChannel
EventInfo         Trigger-level metadata
ArrayS            Dynamic array of uint16_t (ROOT-serializable)
```

### Key types

**EventInfo**

| Method | Description |
|--------|-------------|
| `SetTriggerType(uint16_t)` | Physics / calibration / etc. |
| `SetNHit(uint16_t)` | Number of channels in event |
| `SetTriggerNumber(uint32_t)` | Trigger sequence number |
| `SetEventNumber(uint32_t)` | Event sequence number |
| `SetTriggerTime(uint64_t)` | Trigger timestamp |

**FChannel** (FADC waveform channel)

| Method | Description |
|--------|-------------|
| `SetID(uint16_t)` | Channel ID |
| `SetNdp(int)` | Number of waveform samples |
| `SetWaveform(uint16_t*, int)` | Copy waveform buffer |
| `SetPedestal(uint16_t)` | Pedestal value |
| `GetWaveformHist()` | Returns `TH1D*` of the waveform |

**AChannel** (SADC channel)

| Method | Description |
|--------|-------------|
| `SetID(uint16_t)` | Channel ID |
| `SetADC(uint32_t)` | Integrated ADC count |
| `SetTime(uint32_t)` | Timestamp |

### Example — read a ROOT tree (rootcling macro)

After sourcing `setup_cupdm.sh`, run with:

```bash
root -l read_fadc.C
```

```cpp
// read_fadc.C
{
  gSystem->Load("libRawObjs");

  auto* f = TFile::Open("fadc_test.root");
  auto* t = f->Get<TTree>("t");

  FChannelData* chs = nullptr;
  t->SetBranchAddress("fch", &chs);

  for (Long64_t i = 0; i < t->GetEntries(); ++i) {
    t->GetEntry(i);
    cout << "event " << i << "  nch=" << chs->GetN() << "\n";

    for (int j = 0; j < chs->GetN(); ++j) {
      FChannel* ch = chs->Get(j);
      cout << "  ch " << ch->GetID()
           << "  ndp=" << ch->GetNdp()
           << "  ped=" << ch->GetPedestal() << "\n";
    }
  }
  f->Close();
}
```

To draw a waveform from a specific channel:

```cpp
// draw_waveform.C
{
  gSystem->Load("libRawObjs");

  auto* f = TFile::Open("fadc_test.root");
  auto* t = f->Get<TTree>("t");

  FChannelData* chs = nullptr;
  t->SetBranchAddress("fch", &chs);

  t->GetEntry(0);                    // first event
  FChannel* ch = chs->Get(0);       // first channel
  ch->GetWaveformHist()->Draw();     // draws waveform as TH1D
}
```

---

## HDF5Utils

Buffered HDF5 writer/reader for FADC and SADC data. Supports two storage layouts:

- **Event mode** — channels grouped by trigger, indexed by event number
- **Hit mode** — flat list of self-triggered hits (no event boundary)

### Data types (EDM.hh)

| Type | Fields |
|------|--------|
| `EventInfo_t` | `ttype`, `nhit`, `tnum`, `ttime` |
| `FChannel_t` | `id`, `tbit`, `ped`, `time`, `waveform[16384]` |
| `FChannelHeader_t` | `id`, `tbit`, `ped`, `time` (no waveform) |
| `AChannel_t` | `id`, `tbit`, `adc`, `time` |
| `SubRun_t` | subrun ID, event count, first/last event number |

After sourcing `setup_cupdm.sh`, run with:

```bash
root -l read_fadc_event.C
```

### Event mode — FADC

```cpp
// read_fadc_event.C
#include "EDM.hh"
#include "H5FADCEvent.hh"
#include "H5DataReader.hh"

void read_fadc_event()
{
  gSystem->Load("libHDF5Utils");

  auto* rEvent = new H5FADCEvent();
  auto* reader = new H5DataReader();

  reader->Add("run001.h5");
  reader->Add("run002.h5");   // chain multiple files
  reader->SetData(rEvent);
  reader->Open();

  int n = reader->GetEntries();
  for (int i = 0; i < n; ++i) {
    rEvent->ReadEvent(i);

    EventInfo_t  info = rEvent->GetEventInfo();
    FChannel_t*  data = rEvent->GetData();   // array of info.nhit elements

    cout << "event " << i << "  nhit=" << info.nhit
         << "  tnum=" << info.tnum << "\n";
    for (int j = 0; j < info.nhit; ++j)
      cout << "  ch " << data[j].id << "  wave[0]=" << data[j].waveform[0] << "\n";
  }
  reader->Close();
}
```

### Event mode — SADC

```cpp
// read_sadc_event.C
#include "EDM.hh"
#include "H5SADCEvent.hh"
#include "H5DataReader.hh"

void read_sadc_event()
{
  gSystem->Load("libHDF5Utils");

  auto* rEvent = new H5SADCEvent();
  auto* reader = new H5DataReader();

  reader->Add("run001.h5");
  reader->SetData(rEvent);
  reader->Open();

  int n = reader->GetEntries();
  for (int i = 0; i < n; ++i) {
    rEvent->ReadEvent(i);

    EventInfo_t  info = rEvent->GetEventInfo();
    AChannel_t*  data = rEvent->GetData();   // array of info.nhit elements

    cout << "event " << i << "  nhit=" << info.nhit << "\n";
    for (int j = 0; j < info.nhit; ++j)
      cout << "  ch " << data[j].id << "  adc=" << data[j].adc << "\n";
  }
  reader->Close();
}
```

### Hit mode — FADC (self-triggered)

```cpp
// read_fadc_hit.C
#include "EDM.hh"
#include "H5FADCHit.hh"
#include "H5DataReader.hh"

void read_fadc_hit()
{
  gSystem->Load("libHDF5Utils");

  auto* rHit   = new H5FADCHit();
  auto* reader = new H5DataReader();

  reader->Add("run001.h5");
  reader->SetData(rHit);
  reader->Open();

  int n = reader->GetEntries();   // total number of hits
  for (int i = 0; i < n; ++i) {
    rHit->ReadHit(i);

    const FChannel_t& hit = rHit->GetHit();
    cout << "hit " << i << "  ch=" << hit.id
         << "  time=" << hit.time
         << "  wave[0]=" << hit.waveform[0] << "\n";
  }
  reader->Close();
}
```

### Hit mode — SADC (self-triggered)

```cpp
// read_sadc_hit.C
#include "EDM.hh"
#include "H5SADCHit.hh"
#include "H5DataReader.hh"

void read_sadc_hit()
{
  gSystem->Load("libHDF5Utils");

  auto* rHit   = new H5SADCHit();
  auto* reader = new H5DataReader();

  reader->Add("run001.h5");
  reader->SetData(rHit);
  reader->Open();

  int n = reader->GetEntries();
  for (int i = 0; i < n; ++i) {
    rHit->ReadHit(i);

    const AChannel_t& hit = rHit->GetHit();
    cout << "hit " << i << "  ch=" << hit.id
         << "  adc=" << hit.adc
         << "  time=" << hit.time << "\n";
  }
  reader->Close();
}
```

---

## Repository layout

```
CUPDataModel/
├── CMakeLists.txt
├── RawObjs/
│   ├── inc/          public headers
│   ├── src/          implementation
│   └── test/         write_fadc_root.cc
└── HDF5Utils/
    ├── inc/          public headers (EDM.hh, H5*.hh)
    ├── src/          implementation
    └── test/         test_fadc_event.cc, test_sadc_event.cc, ...
```
