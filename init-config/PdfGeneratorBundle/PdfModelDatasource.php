<?php

declare(strict_types=1);

namespace App\Crudit\Datasource;

use Lle\CruditBundle\Datasource\AbstractDoctrineDatasource;
use Lle\PdfGeneratorBundle\Entity\PdfModel;

class PdfModelDatasource extends AbstractDoctrineDatasource
{
    public function getClassName(): string
    {
        return PdfModel::class;
    }
}
