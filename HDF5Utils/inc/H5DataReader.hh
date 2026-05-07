#pragma once

#include <vector>

#include "EDM.hh"

class AbsH5Base; // Forward declaration changed to AbsH5Base

class H5ChainFile {
public:
  H5ChainFile();
  ~H5ChainFile();

  void AddFile(DataFile_t * file);
  void Close();

  int GetNFile() const;

  // Renamed evtno to local_entry to reflect both Event and Hit indices
  hid_t GetFileId(int entno, int & local_entry, bool * file_changed = nullptr);

private:
  DataFile_t * fCurrentFilePtr{nullptr};
  std::vector<DataFile_t *> fFiles;

};

class H5DataReader {
public:
  H5DataReader();
  explicit H5DataReader(const char * fname);
  ~H5DataReader();

  void SetFilename(const char * fname);
  bool Add(const char * fname);
  bool AddFile(const char * fname);

  // Changed from SetEvent(AbsH5Event*) to SetData(AbsH5Base*)
  void SetData(AbsH5Base * data);

  bool Open();
  void Close();

  int GetEntries() const;

private:
  H5ChainFile * fFiles;
  AbsH5Base * fData;
  int fEntries; // Generalized from fNEvent
  hid_t fSubType;

};

inline void H5DataReader::SetData(AbsH5Base * data) { fData = data; }

inline int H5DataReader::GetEntries() const { return fEntries; }