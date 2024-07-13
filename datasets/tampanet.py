import os
import pandas as pd
import rasterio
import torch
import numpy as np
import glob

from torch.utils.data import Dataset
from torch import Tensor
from rasterio.enums import Resampling
from torchvision import transforms
from .utils import SelectChannels, Unsqueeze, ConvertType, DictTransforms
from .dataset_registry import register_dataset
from functools import partial
from pathlib import Path
from torchgeo.datasets.utils import sort_sentinel2_bands

DATA_DIR = Path("/home/ryan/remote-sensing-image-retrieval/output/tiff")

class TampaNet(Dataset):
    '''
    Test class. Split a Sentinel 2 scene into something that looks like BigEarthNet.
    Note that this is inference ONLY. No labels.

    Blatantly ripping off BigEarthNet
    '''
    
    def __init__(self, dataset_root, transforms):

        self.dataset_root = dataset_root
        self.transforms = transforms
        self.folders = self._load_folders()
        self.image_size = (120, 120)

        assert os.path.isdir(dataset_root), ('Dataset root dir data not found.')

    def __len__(self) -> int:
        return len(self.folders)

    def _load_folders(self):
        items = os.listdir(self.dataset_root)
        folders = [os.path.join(self.dataset_root, item) for item in items]
        return folders

    def _load_paths(self, index: int):
        """Load paths to band files.

        Args:
            index: index to return

        Returns:
            list of file paths
        """
        folder = self.folders[index]
        paths = glob.glob(os.path.join(folder, "*.tif"))
        paths = sorted(paths, key=sort_sentinel2_bands)

        return paths

    def _load_image(self, index: int) -> Tensor:
        """Load a single image.

        Args:
            index: index to return

        Returns:
            the raster image or target
        """
        paths = self._load_paths(index)
        images = []
        for path in paths:
            # Bands are of different spatial resolutions
            # Resample to (120, 120)
            with rasterio.open(path) as dataset:
                array = dataset.read(
                    indexes=1,
                    out_shape=self.image_size,
                    out_dtype="int32",
                    resampling=Resampling.bilinear,
                )
                images.append(array)
        arrays: "np.typing.NDArray[np.int_]" = np.stack(images, axis=0)
        tensor = torch.from_numpy(arrays).float()
        return tensor

    def __getitem__(self, index: int) -> dict[str, Tensor]:
        """Return an index within the dataset.

        Args:
            index: index to return

        Returns:
            data at that index
        """
        image = self._load_image(index)
        path_to_B01 = Path(self._load_paths(index)[0])
        name = path_to_B01.parent.name

        sample = {
            "image": image,
            "name": name
        }

        if self.transforms is not None:
            sample = self.transforms(sample)

        return sample

def init_tampanet(bands, cfg, *args, **kwargs):

    # Init transforms
    image_transforms = [
        SelectChannels(bands),
        ConvertType(torch.float),
        transforms.Resize(size=cfg['model']['img_size'], antialias=True),
        transforms.Normalize(mean=cfg['model']['data_mean'], std=cfg['model']['data_std']),
        Unsqueeze(dim=1) # add time dim
    ]
    tampa_transforms = DictTransforms({'image': transforms.Compose(image_transforms)})    

    # Init dataset
    dataset = TampaNet(
        dataset_root=DATA_DIR,
        transforms=tampa_transforms
    )
    return dataset

# Add dataset to the registry
# Using the six channels from Prithvi
# 1 - B02 Blue
# 2 - B03 Green
# 3 - B04 Red
# 8 - B8A Narrow NIR
# 10 - B11 SWIR 1
# 11 - B12 SWIR 2
register_dataset('TampaNet', partial(init_tampanet, [1, 2, 3, 8, 10, 11]))

